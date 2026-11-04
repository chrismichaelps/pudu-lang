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
const fixture = join(root, 'test-fixtures/ark/UsesArkPlatform.pudu');
const vfsFixture = join(root, 'test-fixtures/ark/UsesArkVfs.pudu');
const modules = ['Ark/Platform/Input.pudu', 'Ark/Platform/Clock.pudu', 'Ark/Platform/Window.pudu', 'Ark/Platform/Vfs.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 300000});
assert.equal(run('run', fixture), 'ark platform: ok\n');
assert.equal(run('run', vfsFixture), 'ark vfs: ok\n');
run('fmt', '--check', fixture, vfsFixture, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-platform-'));
try {
  const typed = join(scratch, 'KeyAsBinding.pudu');
  writeFileSync(typed, 'module KeyAsBinding\nimport Ark.Platform.Input as Input\nexport fn main() -> Int {\n  let map = Input.bind(Input.actions(), "jump", "Space")\n  if Input.bindingsOf(&map, "jump").isEmpty() { 1 } else { 0 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /KeyAsBinding\.pudu:4:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Ark platform input, actions, clock, windows, virtual resources and distribution passed');
