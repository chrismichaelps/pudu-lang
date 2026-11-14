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
const text = join(root, 'test-fixtures/ark/UsesArkText.pudu');
const textBench = join(root, 'bench/TextBench.pudu');
const modules = ['Ark/UI.pudu', 'Ark/Editor/Inspect.pudu', 'Ark/Render/Text.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark ui: ok\n');
assert.equal(run('run', inspect), 'ark inspect: ok\n');
assert.equal(run('run', text), 'ark text: ok\n');
run('fmt', '--check', fixture, inspect, text, textBench, ...modules.map(path => join(library, path)));
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
  const scaled = join(scratch, 'ScaleAsText.pudu');
  writeFileSync(scaled, 'module ScaleAsText\nimport Ark.Math.Color as Color\nimport Ark.Render.Text as Text\nexport fn main() -> Int {\n  let outcome = Text.add(Text.batch(), "hi", 0.0, 0.0, "two", Color.opaque(1.0, 1.0, 1.0))\n  0\n}\n');
  const scaledChecked = spawnSync(binary, ['check', scaled], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(scaledChecked.status, 0);
  assert.match(scaledChecked.stdout + scaledChecked.stderr, /E3001/);
  assert.match(scaledChecked.stdout + scaledChecked.stderr, /ScaleAsText\.pudu:5:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
if (process.argv.includes('--bench')) {
  const timings = Object.fromEntries(run('run', textBench).trim().split('\n').map(line => line.split(' ')).map(([name, ns]) => [name, Number(ns)]));
  console.log(JSON.stringify({screen: '640x480, 40 lines of 80 characters', nanoseconds: timings}));
}
console.log('Ark UI pointer, keyboard focus, rendering, labels, glyph text, derived inspectors, refusals and distribution passed');
