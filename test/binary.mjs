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
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  assert(archive, 'source archive exists');
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  assert(entries.some(entry => entry.endsWith('/lib/Std/Binary.pudu')), 'binary facade ships');
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Binary facade, protocol coexistence, refusals and distribution passed');
