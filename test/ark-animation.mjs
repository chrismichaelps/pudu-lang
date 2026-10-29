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
const fixture = join(root, 'test-fixtures/ark/UsesArkAnimation.pudu');
const ik = join(root, 'test-fixtures/ark/UsesArkIk.pudu');
const bench = join(root, 'bench/IkBench.pudu');
const modules = ['Ark/Animation.pudu', 'Ark/Animation/Machine.pudu', 'Ark/Animation/Ik.pudu', 'Ark/Animation/Limbs.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark animation: ok\n');
assert.equal(run('run', ik), 'ark ik: ok\n');
run('fmt', '--check', fixture, ik, bench, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-animation-'));
try {
  const typed = join(scratch, 'WeightAsText.pudu');
  writeFileSync(typed, 'module WeightAsText\nimport Ark.Animation as Animation\nimport Ark.World.Hierarchy as Hierarchy\nexport fn main() -> Int {\n  let none = Hierarchy.localPoses(&Hierarchy.empty())\n  if Animation.blend(&none, &none, "half") == None { 1 } else { 0 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WeightAsText\.pudu:6:/);
  const softText = join(scratch, 'SoftnessAsText.pudu');
  writeFileSync(softText, 'module SoftnessAsText\nimport Ark.Animation.Ik as Ik\nimport Ark.Math as V\nexport fn main() -> Int {\n  let limb = Ik.Limb{root: V.vec3(0.0, 0.0, 0.0), joint: V.vec3(1.0, 0.0, 0.0), end: V.vec3(2.0, 0.0, 0.0)}\n  let outcome = Ik.twoBone(&limb, V.vec3(1.0, 1.0, 0.0), V.vec3(0.0, 1.0, 0.0), "soft")\n  0\n}\n');
  const soft = spawnSync(binary, ['check', softText], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(soft.status, 0);
  assert.match(soft.stdout + soft.stderr, /E3001/);
  assert.match(soft.stdout + soft.stderr, /SoftnessAsText\.pudu:6:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
if (process.argv.includes('--bench')) {
  const timings = Object.fromEntries(run('run', bench).trim().split('\n').map(line => line.split(' ')).map(([name, ns]) => [name, Number(ns)]));
  console.log(JSON.stringify({nanosecondsPerSolve: timings, batchSpeedup: timings.twoBone / Math.max(timings.twoBoneBatch, 1)}));
}
console.log('Ark animation sampling, blending, layering, state machine, inverse kinematics, refusals and distribution passed');
