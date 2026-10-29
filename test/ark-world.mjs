import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const library = join(root, 'packages/pudu/v0.1/lib');
const env = {...process.env, PUDU_LIB: library};
const fixture = join(root, 'test-fixtures/ark/UsesArkWorld.pudu');
const bench = join(root, 'bench/WorldBench.pudu');
const hierarchy = join(root, 'test-fixtures/ark/UsesArkHierarchy.pudu');
const schedule = join(root, 'test-fixtures/ark/UsesArkSchedule.pudu');
const scheduleBench = join(root, 'bench/ScheduleBench.pudu');
const modules = ['Ark/Core/Handle.pudu', 'Ark/Core/Profile.pudu', 'Ark/World.pudu', 'Ark/World/Commands.pudu', 'Ark/World/Hierarchy.pudu', 'Ark/World/Events.pudu', 'Ark/World/Schedule.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 300000});
assert.equal(run('run', fixture), 'ark world: ok\n');
assert.equal(run('run', hierarchy), 'ark hierarchy: ok\n');
assert.equal(run('run', schedule), 'ark schedule: ok\n');
run('fmt', '--check', fixture, hierarchy, schedule, bench, scheduleBench, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-world-'));
try {
  const typed = join(scratch, 'WorldAsView.pudu');
  writeFileSync(typed, 'module WorldAsView\nimport Ark.World as World\nexport fn main() -> Int {\n  let column = World.columnOf(&World.empty(), "position", 0)\n  if column == None { 0 } else { 1 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WorldAsView\.pudu:4:/);
  const unordered = join(scratch, 'ScheduleWorkers.pudu');
  writeFileSync(unordered, 'module ScheduleWorkers\nimport Ark.World as World\nimport Ark.World.Schedule as Schedule\nexport fn main() -> Int {\n  let Ok(packed) = Schedule.build(&World.empty(), &[]) else { return 1 }\n  let outcome = Schedule.run(World.empty(), &packed, "four")\n  0\n}\n');
  const workers = spawnSync(binary, ['check', unordered], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(workers.status, 0);
  assert.match(workers.stdout + workers.stderr, /E3001/);
  assert.match(workers.stdout + workers.stderr, /ScheduleWorkers\.pudu:6:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
if (process.argv.includes('--bench')) {
  const timings = Object.fromEntries(run('run', bench).trim().split('\n').map(line => line.split(' ')).map(([name, ns]) => [name, Number(ns)]));
  console.log(JSON.stringify({entities: 100000, nanosecondsPerFrame: timings, speedup: timings.records / Math.max(timings.world, 1)}));
  const staged = workers => Object.fromEntries(run('run', scheduleBench, String(workers)).trim().split('\n').map(line => line.split(' ')));
  const [serial, parallel] = [staged(1), staged(4)];
  assert.equal(parallel.checksum, serial.checksum, 'worker counts agree');
  console.log(JSON.stringify({entities: 200000, jobs: 12, nanosecondsPerFrame: {serial: Number(serial.frame), parallel: Number(parallel.frame)}, speedup: Number(serial.frame) / Math.max(Number(parallel.frame), 1)}));
}
console.log('Ark world storage, systems, commands, hierarchy, events, schedules, refusals and distribution passed');
