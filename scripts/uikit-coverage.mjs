import { readFile, readdir, writeFile } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const start = '<!-- uikit-coverage:start -->';
const end = '<!-- uikit-coverage:end -->';

// Checked in this order, so a control is never also counted as a view.
const roots = [
  ['gestures', 'UIGestureRecognizer'],
  ['feedback', 'UIFeedbackGenerator'],
  ['controls', 'UIControl'],
  ['views', 'UIView'],
];
const titles = {
  controls: 'Controls',
  views: 'Views',
  gestures: 'Gestures',
  feedback: 'Feedback',
  traits: 'Accessibility traits',
};
const order = ['controls', 'views', 'gestures', 'feedback', 'traits'];

export function inventory(headers) {
  const parent = new Map();
  const traits = new Set();
  for (const text of headers) {
    for (const [, name, base] of text.matchAll(
      /^@interface\s+(\w+)\s*(?:<[^>\n]*>)?\s*:\s*(\w+)/gm)) {
      parent.set(name, base);
    }
    for (const [name] of text.matchAll(/\bUIAccessibilityTrait[A-Z]\w*/g)) {
      if (name !== 'UIAccessibilityTraitNone') traits.add(name);
    }
  }
  const found = Object.fromEntries(order.map(key => [key, []]));
  for (const name of parent.keys()) {
    const seen = new Set([name]);
    let at = parent.get(name);
    while (at !== undefined && !seen.has(at)) {
      const root = roots.find(([, base]) => base === at);
      if (root) {
        found[root[0]].push(name);
        break;
      }
      seen.add(at);
      at = parent.get(at);
    }
  }
  found.traits = [...traits];
  for (const key of order) {
    if (!found[key].length) throw new Error(`No ${titles[key].toLowerCase()} found in the SDK headers`);
    found[key].sort();
  }
  return found;
}

export function measure(found, hostSource) {
  const used = new Set(hostSource.match(/\b[A-Za-z_]\w*/g) ?? []);
  return Object.fromEntries(order.map(key => [key, {
    covered: found[key].filter(name => used.has(name)),
    missing: found[key].filter(name => !used.has(name)),
  }]));
}

export function render(sdk, report) {
  const names = list => (list.length ? list.map(name => `\`${name}\``).join(', ') : 'none');
  const rows = order.map(key => {
    const { covered, missing } = report[key];
    return `| ${titles[key]} | ${covered.length} of ${covered.length + missing.length} `
      + `| ${names(covered)} | ${names(missing)} |`;
  });
  return [
    `Measured against \`${sdk}\`.`,
    '',
    '| Category | Covered | In the host | Not in the host |',
    '| --- | --- | --- | --- |',
    ...rows,
  ].join('\n');
}

export function recorded(page) {
  const block = page.slice(page.indexOf(start) + start.length, page.indexOf(end));
  const sdk = block.match(/^Measured against `([^`]+)`\.$/m);
  return {
    sdk: sdk ? sdk[1] : null,
    names: new Set([...block.matchAll(/`(UI\w+)`/g)].map(([, name]) => name)),
  };
}

export function update(page, block) {
  if (page.split(start).length !== 2 || page.split(end).length !== 2
      || page.indexOf(start) >= page.indexOf(end)) {
    throw new Error('Expected one ordered uikit-coverage marker pair');
  }
  const before = page.slice(0, page.indexOf(start) + start.length);
  const after = page.slice(page.indexOf(end));
  return `${before}\n${block}\n${after}`;
}

async function readAll(directory, keep) {
  const names = (await readdir(directory)).filter(keep).sort();
  if (!names.length) throw new Error(`No matching files in ${directory}`);
  return Promise.all(names.map(name => readFile(`${directory}/${name}`, 'utf8')));
}

function sdkPath() {
  const xcrun = process.env.PUDU_XCRUN || 'xcrun';
  try {
    return execFileSync(xcrun, ['--sdk', 'iphonesimulator', '--show-sdk-path'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  } catch {
    throw new Error('The iOS simulator SDK was not found; install Xcode or set PUDU_XCRUN');
  }
}

async function main() {
  const mode = process.argv.slice(2);
  if (mode.length !== 1 || !['--report', '--check', '--write'].includes(mode[0])) {
    throw new Error('Usage: node scripts/uikit-coverage.mjs --report|--check|--write');
  }
  const root = fileURLToPath(new URL('../', import.meta.url));
  const sdk = sdkPath();
  const headers = await readAll(
    `${sdk}/System/Library/Frameworks/UIKit.framework/Headers`, name => name.endsWith('.h'));
  const host = await readAll(
    `${root}packages/pudu/v0.1/cbits`, name => /^pudu_ios_.*\.[hm]$/.test(name));
  const found = inventory(headers);
  const sdkName = basename(sdk, '.sdk');
  const block = render(sdkName, measure(found, host.join('\n')));
  if (mode[0] === '--report') {
    console.log(block);
    return;
  }
  const pagePath = `${root}wiki/architecture/NATIVE-IOS-UI.md`;
  const page = await readFile(pagePath, 'utf8');
  const next = update(page, block);
  if (mode[0] === '--write') {
    if (next !== page) await writeFile(pagePath, next);
    return;
  }
  if (next === page) return;
  const known = recorded(page);
  if (known.sdk === sdkName) {
    throw new Error('The measured UIKit inventory is stale; run with --write');
  }
  const added = order.flatMap(key => found[key]).filter(name => !known.names.has(name));
  console.log(`Recorded against ${known.sdk ?? 'no SDK'}; installed is ${sdkName}.`);
  console.log(added.length
    ? `Not in the recorded inventory: ${added.join(', ')}`
    : 'The installed SDK adds no classes or traits to the recorded inventory.');
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
