import { readFile, writeFile } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const start = '<!-- native-progress:start -->';
const end = '<!-- native-progress:end -->';

export function coverage(source) {
  const section = source.match(/^## Coverage ledger\r?\n([\s\S]*?)(?=^## |$(?![\s\S]))/m);
  if (!section) throw new Error('Missing Coverage ledger section');
  const lines = section[1].trim().split(/\r?\n/);
  if (lines.shift() !== '| Area | State | Next obligation |'
      || lines.shift() !== '| --- | --- | --- |') {
    throw new Error('Invalid coverage table header');
  }
  const areas = new Set();
  let complete = 0;
  for (const line of lines) {
    const row = line.match(/^\| ([^|]+) \| ([^|]+) \| ([^|]+) \|$/);
    if (!row) throw new Error(`Invalid coverage row: ${line}`);
    const [, area, state] = row.map(value => value.trim());
    if (!area) throw new Error('Empty coverage area');
    if (areas.has(area)) throw new Error(`Duplicate coverage area: ${area}`);
    if (!/^(Implemented|Partial|Pending)( \([^)]+\))?$/.test(state)) {
      throw new Error(`Unknown coverage state: ${state}`);
    }
    areas.add(area);
    if (state.startsWith('Implemented')) complete++;
  }
  if (!areas.size) throw new Error('Empty coverage table');
  return { complete, total: areas.size };
}

export function render({ complete, total }) {
  if (!Number.isSafeInteger(complete) || !Number.isSafeInteger(total)
      || total <= 0 || complete < 0 || complete > total) {
    throw new Error('Invalid coverage counts');
  }
  const cells = Math.floor(20 * complete / total);
  const percent = Math.floor(100 * complete / total);
  return `**C11 emission progress:** [${'█'.repeat(cells)}${'░'.repeat(20 - cells)}] **${percent}%** (${complete}/${total} coverage areas complete)\n\n`
    + 'Counts completed areas in the [native coverage ledger](wiki/architecture/NATIVE-EMISSION.md). '
    + 'Partial areas count as incomplete; this is not a percentage of language constructs. '
    + 'Updated automatically after merges into `dev`.';
}

export function updateReadme(readme, counts) {
  if (readme.split(start).length !== 2 || readme.split(end).length !== 2
      || readme.indexOf(start) >= readme.indexOf(end)) {
    throw new Error('Expected one ordered native-progress marker pair');
  }
  const before = readme.slice(0, readme.indexOf(start) + start.length);
  const after = readme.slice(readme.indexOf(end));
  return `${before}\n${render(counts)}\n${after}`;
}

async function main() {
  const mode = process.argv.slice(2);
  if (mode.length !== 1 || !['--check', '--write'].includes(mode[0])) {
    throw new Error('Usage: node scripts/native-progress.mjs --check|--write');
  }
  const root = new URL('../', import.meta.url);
  const readmePath = new URL('README.md', root);
  const ledger = await readFile(new URL('wiki/architecture/NATIVE-EMISSION.md', root), 'utf8');
  const readme = await readFile(readmePath, 'utf8');
  const next = updateReadme(readme, coverage(ledger));
  if (next === readme) return;
  if (mode[0] === '--check') throw new Error('README native progress is stale; run with --write');
  await writeFile(readmePath, next);
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
