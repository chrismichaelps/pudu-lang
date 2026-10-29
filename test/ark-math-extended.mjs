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
const fixture = join(root, 'test-fixtures/ark/UsesArkMathExtended.pudu');
const modules = ['Vec2', 'Matrix', 'Quat', 'Transform', 'Camera', 'Geometry', 'Color', 'Random', 'Noise'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
run('check', fixture);
assert.equal(run('run', fixture), 'ark math extended: ok\n');
run('fmt', '--check', fixture, join(library, 'Ark/Math.pudu'), ...modules.map(name => join(library, `Ark/Math/${name}.pudu`)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-math-extended-'));
try {
  for (const [name, call] of [
    ['PlanarIntoSpatial', 'Q.rotate(Q.identity(), P.vec2(1.0, 0.0))'],
    ['NarrowRandomSeed', 'Random.seeded(7u32)'],
    ['MatrixAsTransform', 'T.transformPoint(M.identity4(), V.vec3(0.0, 0.0, 0.0))'],
  ]) {
    const path = join(scratch, name + '.pudu');
    writeFileSync(path, `module ${name}\nimport Ark.Math as V\nimport Ark.Math.Vec2 as P\nimport Ark.Math.Matrix as M\nimport Ark.Math.Quat as Q\nimport Ark.Math.Transform as T\nimport Ark.Math.Random as Random\nexport fn main() -> Int {\n  let value = ${call}\n  display(value)\n  0\n}\n`);
    const result = spawnSync(binary, ['check', path], {env, encoding: 'utf8', timeout: 60000});
    assert.ifError(result.error);
    assert.notEqual(result.status, 0, name);
    assert.match(result.stderr + result.stdout, /E3001/, name);
    assert.match(result.stderr + result.stdout, new RegExp(name + '\\.pudu:9:'), name);
  }
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  assert(archive, 'source archive was not created');
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const name of modules) assert(entries.some(path => path.endsWith(`/lib/Ark/Math/${name}.pudu`)), name);
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Ark extended math, degenerate refusals, type refusals and distribution passed');
