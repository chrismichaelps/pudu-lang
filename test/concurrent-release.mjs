import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const fixture = join(root, 'test-fixtures/stdlib/ReleasesConcurrent.pudu');
const live = (path, rounds) => {
  const run = spawnSync(binary, ['+RTS', '-t', '--machine-readable', '-RTS', 'run', fixture, path, String(rounds)], {env, encoding: 'utf8', timeout: 300000});
  assert.equal(run.status, 0, run.stderr);
  assert.equal(run.stdout, `rounds ${rounds}\n`);
  const bytes = Number((run.stderr.match(/\("max_live_bytes", "(\d+)"\)/) ?? [])[1]);
  assert(Number.isInteger(bytes), 'runtime statistics report max_live_bytes');
  return bytes;
};
const report = [];
for (const path of ['ok', 'fail', 'parallel']) {
  const small = live(path, 500);
  const large = live(path, 5000);
  assert(large < small * 2 + 4 * 1024 * 1024, `${path}: ${large} live bytes at 5,000 rounds against ${small} at 500`);
  report.push(`${path} ${small}/${large}`);
}
const formatted = spawnSync(binary, ['fmt', '--check', fixture], {env, encoding: 'utf8', timeout: 60000});
assert.equal(formatted.status, 0, formatted.stdout + formatted.stderr);
console.log(`Concurrent helpers release what they create (live bytes at 500/5,000 rounds: ${report.join(', ')})`);
