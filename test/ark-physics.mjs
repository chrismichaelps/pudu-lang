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
const modules = ['Ark/Physics.pudu', ...['Contact', 'Step', 'Query'].map(name => `Ark/Physics/${name}.pudu`)];
const fixtures = ['UsesArkPhysics', 'UsesArkPhysicsBoundary'].map(name => join(root, `test-fixtures/ark/${name}.pudu`));
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixtures[0]), 'ark physics: ok\n');
assert.equal(run('run', fixtures[1]), 'ark physics boundaries: ok\n');
run('fmt', '--check', ...fixtures, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-physics-'));
try {
  const refused = join(scratch, 'WrongMass.pudu');
  writeFileSync(refused, 'module WrongMass\nimport Ark.Math as V\nimport Ark.Physics as Physics\nexport fn main() -> Int {\n  let body = Physics.Body{position: V.vec3(0.0, 0.0, 0.0), velocity: V.vec3(0.0, 0.0, 0.0), mass: "heavy", restitution: 0.0, friction: 0.0, shape: Physics.Shape{kind: "box", extent: V.vec3(1.0, 1.0, 1.0)}}\n  0\n}\n');
  const checked = spawnSync(binary, ['check', refused], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WrongMass\.pudu:5:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Ark physics scenarios, boundaries, disjoint batches, diagnostics and shipping passed');
