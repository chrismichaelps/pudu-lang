import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, mkdir, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {analyze, parsePudu} from '../scripts/app-layers/model.mjs';

const node = (name, imports = []) => ({name, imports, path: name.replaceAll('.', '/') + '.pudu', lines: 1});
const command = args => spawnSync(process.execPath, ['scripts/app-layers.mjs', ...args], {encoding: 'utf8'});

test('scanner masks nested comments and escaped literals', () => {
  const source = '/* import Hidden.One /* module Fake */ */\nmodule Std.App\n// import Hidden.Two\n' +
    'import Std.App.Stage {Stage}\nimport Std.App.Stage as Lifecycle\n' +
    'fn text() -> Str { "import Hidden.Three\\\"" }\n';
  assert.deepEqual(parsePudu(source, 'App.pudu').imports, ['Std.App.Stage']);
  assert.throws(() => parsePudu('/* open', 'bad'), /unterminated block/);
  assert.throws(() => parsePudu('module Std.App\n"open', 'bad'), /unterminated quoted/);
  assert.throws(() => parsePudu('module A\nmodule B', 'bad'), /one module/);
  assert.deepEqual(parsePudu('module Std.App\nimport Std.One {\nitem\n}\nimport Std.Árbol as Árbol\nfn main() => 0', 'App').imports,
    ['Std.One', 'Std.Árbol']);
  assert.throws(() => parsePudu('module Std.App\nimport Std.One {', 'bad'), /unterminated import/);
  assert.deepEqual(parsePudu('module Std.App\nimport Std.One as É\nimport Std.Two\n', 'App').imports,
    ['Std.One', 'Std.Two']);
});

test('explicit layers reject upward edges and missing classification', () => {
  const valid = [node('Std.App', ['Std.App.Stage']), node('Std.App.Stage')];
  assert.deepEqual(analyze(valid).findings, []);
  assert.deepEqual(analyze([...valid, node('Std.Db.Driver', ['Std.App'])]).findings,
    ['upward import: Std.Db.Driver [1] -> Std.App [10]']);
  assert.deepEqual(analyze([node('Std.App.NewService')]).findings, ['unclassified module: Std.App.NewService']);
  assert.deepEqual(analyze([node('Std.App', ['Std.Missing'])]).findings, ['missing import: Std.App -> Std.Missing']);
});

test('foundation closure cannot depend on specialized services', () => {
  const report = analyze([node('Std.App', ['Std.Core']), node('Std.Core', ['Std.Db.Driver']), node('Std.Db.Driver')]);
  assert.deepEqual(report.findings, ['upward import: Std.Core [0] -> Std.Db.Driver [1]']);
  assert.equal(report.frameworkModules, 3);
});

test('cycles, duplicates and long chains remain explicit and deterministic', () => {
  const cycle = [node('Std.A', ['Std.B']), node('Std.B', ['Std.A'])];
  assert.deepEqual(analyze(cycle).findings, ['import cycle: Std.A, Std.B']);
  assert.deepEqual(analyze([node('Std.A', ['Std.A'])]).findings, ['import cycle: Std.A']);
  assert.throws(() => analyze([node('Std.A'), node('Std.A')]), /duplicate module/);
  assert.deepEqual(analyze(cycle), analyze(cycle.reverse()));
  const chain = Array.from({length: 3000}, (_, index) => node(`Std.N${index}`, index ? [`Std.N${index - 1}`] : []));
  chain.push(node('Std.App', ['Std.N2999']));
  const report = analyze(chain);
  assert.deepEqual(report.findings, []);
  assert.equal(report.modules.find(module => module.name === 'Std.App').depth, 3000);
});

test('actual library and malformed source roots produce exact command results', async () => {
  const actual = command(['--json']);
  assert.equal(actual.status, 0, actual.stderr);
  assert.deepEqual(JSON.parse(actual.stdout).findings, []);
  assert.equal(command(['--unexpected']).status, 1);
  const root = await mkdtemp(join(tmpdir(), 'pudu-app-layers-'));
  try {
    assert.equal(command(['--root', root]).status, 1);
    await mkdir(join(root, 'Std'));
    await writeFile(join(root, 'Std', 'App.pudu'), 'module Std.Wrong\n');
    const mismatch = command(['--root', root]);
    assert.equal(mismatch.status, 1); assert.match(mismatch.stderr, /module path mismatch/);
    await writeFile(join(root, 'Std', 'App.pudu'), 'module Std.App\nimport Std.Missing\n');
    const missing = command(['--root', root, '--json']);
    assert.equal(missing.status, 1);
    assert.deepEqual(JSON.parse(missing.stdout).findings, ['missing import: Std.App -> Std.Missing']);
  } finally { await rm(root, {recursive: true, force: true}); }
});
