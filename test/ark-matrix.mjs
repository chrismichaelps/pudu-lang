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
const fixture = join(root, 'test-fixtures/ark/UsesArkMatrix.pudu');
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 60000});
run('check', fixture);
assert.equal(run('run', fixture), 'ark matrix: ok\n');
run('fmt', '--check', fixture, join(library, 'Ark/Math.pudu'), join(library, 'Ark/Math/Matrix.pudu'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-matrix-'));
try {
  for (const [name, call] of [
    ['WrongDimension', 'Matrix.transform4(Matrix.identity4(), Vector.vec3(1.0, 2.0, 3.0))'],
    ['WrongPrecision', 'Vector.vec4(1.0f32, 0.0, 0.0, 1.0)'],
  ]) {
    const path = join(scratch, name + '.pudu');
    writeFileSync(path, `module ${name}\nimport Ark.Math as Vector\nimport Ark.Math.Matrix as Matrix\nexport fn main() -> Int {\n  let value = ${call}\n  display(value)\n  0\n}\n`);
    const result = spawnSync(binary, ['check', path], {env, encoding: 'utf8', timeout: 60000});
    assert.ifError(result.error);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr + result.stdout, /E3001/);
    assert.match(result.stderr + result.stdout, new RegExp(name + '\\.pudu:5:'));
  }
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  assert(archive, 'source archive was not created');
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'});
  assert(entries.split('\n').some(path => path.endsWith('/lib/Ark/Math/Matrix.pudu')));
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Ark matrix algebra, projection refusals, precision and nested distribution passed');
