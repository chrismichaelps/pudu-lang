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
const modules = ['Ark/Math/Distance.pudu', 'Ark/Physics/Cast.pudu'];
const fixture = join(root, 'test-fixtures/ark/UsesArkCast.pudu');
const env = {...process.env, PUDU_LIB: library};
const run = (...args) => execFileSync(binary, args, {cwd: root, env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark cast: ok\n');
run('fmt', '--check', ...modules.map(path => join(library, path)), fixture, join(root, 'bench/CastBench.pudu'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-cast-'));
try {
  const refused = join(scratch, 'WrongRadius.pudu');
  writeFileSync(refused, 'module WrongRadius\nimport Ark.Math as V\nimport Ark.Physics.Cast as Cast\nexport fn main() -> Int {\n  let request = Cast.CapsuleBox{start: V.vec3(0.0, 0.0, 0.0), end: V.vec3(0.0, 0.0, 0.0), radius: "wide", displacement: V.vec3(0.0, 0.0, 0.0), minimum: V.vec3(-1.0, -1.0, -1.0), maximum: V.vec3(1.0, 1.0, 1.0), tolerance: 0.01, maxIterations: 32}\n  0\n}\n');
  const checked = spawnSync(binary, ['check', refused], {cwd: root, env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WrongRadius\.pudu:5:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const paths = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const module of modules) assert(paths.some(path => path.endsWith('/lib/' + module)), module);
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Ark closest witnesses, capsule casts, typed refusals and shipping passed');
