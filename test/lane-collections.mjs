import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const fixture = join(root, 'test-fixtures/lanes/LaneCollections.pudu');
const bench = join(root, 'bench/LaneParallel.pudu');
const statistics = (path, rts = []) => {
  const run = spawnSync(binary, ['+RTS', ...rts, '-t', '--machine-readable', '-RTS', 'run', path], {env, encoding: 'utf8', timeout: 300000});
  assert.equal(run.status, 0, run.stderr);
  const collections = Number((run.stderr.match(/\("num_GCs", "(\d+)"\)/) ?? [])[1]);
  assert(Number.isInteger(collections), 'runtime statistics report num_GCs');
  return {output: run.stdout, collections};
};
const serial = statistics(fixture);
assert.equal(serial.output, 'true\n');
assert(serial.collections < 100, `${serial.collections} collections for 400 lane kernel calls`);
for (const capabilities of ['-N1', '-N2']) {
  const {collections} = statistics(fixture, [capabilities]);
  assert(collections < 100, `${collections} collections for 400 lane kernel calls at ${capabilities}`);
}
const parallel = statistics(bench);
assert.match(parallel.output, /^lanes one \d+ ms, four \d+ ms\nloops one \d+ ms, four \d+ ms\n$/);
const formatted = spawnSync(binary, ['fmt', '--check', fixture, bench], {env, encoding: 'utf8', timeout: 60000});
assert.equal(formatted.status, 0, formatted.stdout + formatted.stderr);
console.log(`Lane kernels shared ${serial.collections} collections across 400 calls; ${parallel.output.trim().replace('\n', '; ')}`);
