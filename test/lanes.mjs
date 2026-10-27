import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const library = join(root, 'packages/pudu/v0.1/lib');
const env = {...process.env, PUDU_LIB: library};
const fixture = join(root, 'test-fixtures/lanes/UsesLanes.pudu');
const bench = join(root, 'bench/LanesBench.pudu');
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 180000});
assert.equal(run('run', fixture), 'lanes: ok\n');
const raster = join(root, 'test-fixtures/lanes/UsesRaster.pudu');
assert.equal(run('run', raster), 'raster: ok\n');
run('fmt', '--check', fixture, raster, bench, join(library, 'Std/Lanes.pudu'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-lanes-'));
try {
  const typed = join(scratch, 'ArrayAsLanes.pudu');
  writeFileSync(typed, 'module ArrayAsLanes\nimport Std.Lanes as Lanes\nexport fn main() -> Int {\n  let total = Lanes.sum(&[1.0, 2.0])\n  if total > 0.0 { 0 } else { 1 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /ArrayAsLanes\.pudu:4:/);
  const partial = join(scratch, 'PartialValue.pudu');
  writeFileSync(partial, 'module PartialValue\nexport fn main() -> Int {\n  let total = lanesSum(bytesOf([1u8, 2u8, 3u8]))\n  if total > 0.0 { 0 } else { 1 }\n}\n');
  const aborted = spawnSync(binary, ['run', partial], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(aborted.status, 0);
  assert.match(aborted.stdout + aborted.stderr, /E7012/);
  assert.match(aborted.stdout + aborted.stderr, /whole binary64 values/);
} finally { rmSync(scratch, {recursive: true, force: true}); }
if (process.argv.includes('--bench')) {
  const timings = Object.fromEntries(run('run', bench).trim().split('\n').map(line => line.split(' ')).map(([name, ms]) => [name, Number(ms)]));
  console.log(JSON.stringify({elements: 100000, frames: 10, milliseconds: timings, speedup: timings.array / Math.max(timings.lanes, 1)}));
}
console.log('lanes kernels, refusals and formatting passed');
