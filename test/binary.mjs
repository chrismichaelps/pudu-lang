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
const fixture = join(root, 'test-fixtures/stdlib/BinarySmoke.pudu');
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'binary facade: ok\n');
run('fmt', '--check', fixture, join(library, 'Std/Binary.pudu'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-binary-'));
try {
  const wrong = join(scratch, 'WrongBinary.pudu');
  writeFileSync(wrong, 'module WrongBinary\nimport Std.Binary as Binary\nexport fn main() -> Int {\n  let answer = Binary.decode(&"text")\n  0\n}\n');
  const checked = spawnSync(binary, ['check', wrong], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WrongBinary\.pudu:4:/);
  const writer = join(scratch, 'WriterBinary.pudu');
  for (const [setup, accepted] of [
    ['var node: Binary.Node = Binary.Absent\n  for _index in 0..512 { node = Binary.Present(node) }', true],
    ['var node: Binary.Node = Binary.Absent\n  for _index in 0..513 { node = Binary.Present(node) }', false],
    ['let node = Binary.Fields([("x", Binary.Absent), ("x", Binary.Absent)])', false],
    ['let node = Binary.Choice("Stored", [("x", Binary.Absent), ("x", Binary.Absent)])', false],
  ]) {
    writeFileSync(writer, 'module WriterBinary\nimport Std.Binary as Binary\nexport fn main() -> Int {\n  ' + setup +
      '\n  let bytes = Binary.encode(&node)\n  let Ok(_) = Binary.decode(&bytes) else { panic("writer emitted unreadable bytes") }\n  0\n}\n');
    const result = spawnSync(binary, ['run', writer], {env, encoding: 'utf8', timeout: 60000});
    if (accepted) {
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.equal(result.stdout, '');
    } else {
      assert.notEqual(result.status, 0, setup);
      assert.match(result.stdout + result.stderr, /E7001/);
      assert.match(result.stdout + result.stderr, /WriterBinary\.pudu:\d+:\d+/);
    }
  }
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  assert(archive, 'source archive exists');
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  assert(entries.some(entry => entry.endsWith('/lib/Std/Binary.pudu')), 'binary facade ships');
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Binary facade, protocol coexistence, refusals and distribution passed');
