import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const fixture = join(root, 'test-fixtures/desktop/ConfiguresDesktop.pudu');
const run = spawnSync(binary, ['run', fixture], {env, encoding: 'utf8', timeout: 60000});
assert.equal(run.status, 0, run.stderr);
assert.equal(run.stdout, [
  'desktop density must be between 250 and 8000 thousandths',
  'desktop density must be between 250 and 8000 thousandths',
  'desktop size limits cannot be negative',
  'desktop size limits exceed the platform limit',
  'desktop minimum size exceeds its maximum',
  'desktop aspect ratio needs both terms',
  'desktop aspect ratio must be positive',
  'valid settings refused for the missing window',
  '',
].join('\n'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-desktop-configure-'));
try {
  const typed = join(scratch, 'FloatDensity.pudu');
  writeFileSync(typed, 'module FloatDensity\nexport fn main() -> Int {\n  let outcome = desktopConfigure(1, 2.0, 0, 0, 0, 0, 0, 0, false)\n  0\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /FloatDensity\.pudu:3:/);
} finally { rmSync(scratch, {recursive: true, force: true}); }
const formatted = spawnSync(binary, ['fmt', '--check', fixture], {env, encoding: 'utf8', timeout: 60000});
assert.equal(formatted.status, 0, formatted.stdout + formatted.stderr);
console.log('Desktop configure refusals, missing-window failure and argument types passed');
