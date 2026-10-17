import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, copyFile, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { coverage, render, updateReadme } from '../scripts/native-progress.mjs';

const table = rows => `## Coverage ledger\n\n| Area | State | Next obligation |\n| --- | --- | --- |\n${rows}\n`;
const row = (name, state) => `| ${name} | ${state} | Preserve evidence |`;
const readme = 'Introduction\n<!-- native-progress:start -->\nold\n<!-- native-progress:end -->\nInstallation\n';

test('counts completed areas without granting partial credit', () => {
  const source = table([
    row('Scalars', 'Implemented (#488, #491)'),
    row('Errors', 'Partial (#494)'),
    row('Host', 'Pending'),
  ].join('\n')) + '\n## Other section\nIgnored\n';
  assert.deepEqual(coverage(source), { complete: 1, total: 3 });
  assert.deepEqual(coverage(source.replaceAll('\n', '\r\n')), { complete: 1, total: 3 });
  assert.match(render(coverage(source)), /\[██████░░░░░░░░░░░░░░\] \*\*33%\*\* \(1\/3 coverage areas complete\)/);
});

test('rounds down and renders zero and full completion exactly', () => {
  assert.match(render({ complete: 4, total: 14 }), /\[█████░░░░░░░░░░░░░░░\] \*\*28%\*\*/);
  assert.match(render({ complete: 0, total: 1 }), /\[░{20}\] \*\*0%\*\*/);
  assert.match(render({ complete: 1, total: 1 }), /\[█{20}\] \*\*100%\*\*/);
  for (const counts of [{ complete: 0, total: 0 }, { complete: 2, total: 1 }, { complete: -1, total: 3 }]) {
    assert.throws(() => render(counts), /Invalid coverage counts/);
  }
});

test('rejects missing, empty, duplicate, malformed and unknown ledger input', () => {
  for (const source of [
    '', table(''), table(row(' ', 'Implemented')), table(row('Scalars', 'Mostly done')),
    table([row('Scalars', 'Implemented'), row('Scalars', 'Pending')].join('\n')),
    table('| broken |'), table(row('Scalars', 'Implemented')).replace('Next obligation', 'Other'),
  ]) assert.throws(() => coverage(source));
});

test('preserves surrounding README and updates idempotently', () => {
  const updated = updateReadme(readme, { complete: 1, total: 1 });
  assert.ok(updated.startsWith('Introduction\n<!-- native-progress:start -->\n'));
  assert.ok(updated.endsWith('\n<!-- native-progress:end -->\nInstallation\n'));
  assert.match(updated, /\*\*100%\*\* \(1\/1 coverage areas complete\)/);
  assert.equal(updateReadme(updated, { complete: 1, total: 1 }), updated);
  for (const invalid of ['', readme + readme, readme.replace('native-progress:start', 'native-progress:end')]) {
    assert.throws(() => updateReadme(invalid, { complete: 0, total: 1 }), /marker pair/);
  }
  assert.throws(() => updateReadme('<!-- native-progress:end --><!-- native-progress:start -->', { complete: 0, total: 1 }));
});

test('CLI checks stale output, writes from any cwd, and refuses invalid input without edits', async () => {
  const root = await mkdtemp(join(tmpdir(), 'pudu-progress-'));
  try {
    await mkdir(join(root, 'scripts'));
    await mkdir(join(root, 'wiki/architecture'), { recursive: true });
    const script = join(root, 'scripts/native-progress.mjs');
    const target = join(root, 'README.md');
    const ledger = join(root, 'wiki/architecture/NATIVE-EMISSION.md');
    await copyFile(new URL('../scripts/native-progress.mjs', import.meta.url), script);
    await writeFile(target, readme);
    await writeFile(ledger, table(row('Scalars', 'Implemented')));
    const run = mode => spawnSync(process.execPath, [script, mode], { cwd: tmpdir(), encoding: 'utf8' });
    assert.match(run('--check').stderr, /stale/);
    assert.equal(run('--check').status, 1);
    assert.equal(await readFile(target, 'utf8'), readme);
    assert.equal(run('--write').status, 0);
    assert.equal(run('--check').status, 0);
    const updated = await readFile(target, 'utf8');
    assert.match(updated, /\*\*100%\*\*/);
    assert.equal(run('--write').status, 0);
    assert.equal(await readFile(target, 'utf8'), updated);
    await writeFile(ledger, table(row('Scalars', 'Almost')));
    assert.equal(run('--write').status, 1);
    assert.equal(await readFile(target, 'utf8'), updated);
    assert.match(run('--other').stderr, /Usage:/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
