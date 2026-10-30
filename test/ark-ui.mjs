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
const fixture = join(root, 'test-fixtures/ark/UsesArkUI.pudu');
const inspect = join(root, 'test-fixtures/ark/UsesArkInspect.pudu');
const modules = ['Ark/UI.pudu', 'Ark/Editor/Inspect.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark ui: ok\n');
assert.equal(run('run', inspect), 'ark inspect: ok\n');
run('fmt', '--check', fixture, inspect, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-ui-'));
try {
  const typed = join(scratch, 'WidthAsText.pudu');
  writeFileSync(typed, 'module WidthAsText\nimport Ark.UI as UI\nexport fn main() -> Int {\n  let inside = UI.contains(&UI.Rect{x: 0.0, y: 0.0, width: 1.0, height: 1.0}, 0.5, 0.5)\n  let wide = UI.Rect{x: 0.0, y: 0.0, width: "wide", height: 1.0}\n  if inside { 0 } else { 1 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WidthAsText\.pudu:5:/);
  const path = join(scratch, 'PathAsNumber.pudu');
  writeFileSync(path, 'module PathAsNumber\nimport Ark.Editor.Inspect as Inspect\ntype Knob = { level: Float64 } derives Inspect.Inspect\nexport fn main() -> Int {\n  let knob = Knob{level: 1.0}\n  let outcome = Inspect.edit(&knob, 3, "2.0")\n  0\n}\n');
  const pathChecked = spawnSync(binary, ['check', path], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(pathChecked.status, 0);
  assert.match(pathChecked.stdout + pathChecked.stderr, /E3001/);
  assert.match(pathChecked.stdout + pathChecked.stderr, /PathAsNumber\.pudu:6:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Ark UI pointer, keyboard focus, rendering, derived inspectors, refusals and distribution passed');
