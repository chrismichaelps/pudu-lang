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
const fixture = join(root, 'test-fixtures/ark/UsesArkAudio.pudu');
const modules = ['Ark/Audio.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark audio: ok\n');
run('fmt', '--check', fixture, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-audio-'));
try {
  const typed = join(scratch, 'GainAsText.pudu');
  writeFileSync(typed, 'module GainAsText\nimport Ark.Audio as Audio\nexport fn main() -> Int {\n  let Some(mixer) = Audio.create(48000, Audio.Rolloff{model: "none", near: 1.0, far: 2.0}) else { return 1 }\n  if Audio.setBus(mixer, "music", "loud") == None { 1 } else { 0 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /GainAsText\.pudu:5:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Ark audio mixing, buses, spatialization, PCM output, refusals and distribution passed');
