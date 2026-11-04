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
const fixture = join(root, 'test-fixtures/ark/UsesArkGame.pudu');
const modules = ['Ark/Game.pudu', 'Ark/Game/Camera.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark game: ok\n');
run('fmt', '--check', fixture, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-game-'));
try {
  const typed = join(scratch, 'ZoomAsText.pudu');
  writeFileSync(typed, 'module ZoomAsText\nimport Ark.Game.Camera as Camera\nimport Ark.Math as V\nexport fn main() -> Int {\n  let Some(rig) = Camera.orbit(V.vec3(0.0, 0.0, 0.0), 1.0, 0.0, 0.0) else { return 1 }\n  if Camera.steer(rig, 0.0, 0.0, "closer") == None { 1 } else { 0 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /ZoomAsText\.pudu:6:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Ark game loop, scene stack, camera rigs, refusals and distribution passed');
