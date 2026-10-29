import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const modulePath = 'Ark/Physics/Character.pudu';
const module = join(root, 'packages/pudu/v0.1/lib', modulePath);
const fixture = join(root, 'test-fixtures/ark/UsesArkCharacter.pudu');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const run = (...args) => execFileSync(binary, args, {cwd: root, env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark character: ok\n');
run('fmt', '--check', module, fixture);
const scratch = mkdtempSync(join(tmpdir(), 'pudu-character-'));
try {
  const refused = join(scratch, 'WrongRadius.pudu');
  writeFileSync(refused, 'module WrongRadius\nimport Ark.Math as V\nimport Ark.Physics.Character as C\nexport fn main() -> Int {\n  let capsule = C.Capsule{position: V.vec3(0.0, 0.0, 0.0), radius: "wide", halfHeight: 1.0, up: V.vec3(0.0, 1.0, 0.0)}\n  0\n}\n');
  const result = spawnSync(binary, ['check', refused], {cwd: root, env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /E3001/);
  assert.match(result.stdout + result.stderr, /WrongRadius\.pudu:5:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  assert(execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n').some(path => path.endsWith('/lib/' + modulePath)));
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Ark capsule sweeps, sliding, support, refusals and shipping passed');
