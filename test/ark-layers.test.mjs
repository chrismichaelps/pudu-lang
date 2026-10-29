import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import test from 'node:test';
import {analyze} from '../scripts/ark-layers/model.mjs';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const node = (name, imports = []) => ({name, imports, path: name.replaceAll('.', '/') + '.pudu'});
const run = (...args) => spawnSync(process.execPath, [join(root, 'scripts/ark-layers.mjs'), ...args], {encoding: 'utf8'});

test('all engine roots carry explicit layers and retain same-root composition', () => {
  const groups = [['Math', 'Core'], ['Platform'], ['Assets', 'World'],
    ['Render', 'Physics', 'Audio', 'Net'], ['Animation', 'UI'], ['Game'], ['Editor', 'Tools'], ['Build']];
  const sources = groups.flatMap(names => names.map(name => node(`Ark.${name}`)));
  sources.push(node('Ark.Math.Matrix', ['Ark.Math']), node('Ark.Game.Scene', ['Ark.World', 'Ark.Render', 'Std', 'Std.Option']), node('Std'), node('Std.Option'));
  const report = analyze(sources);
  assert.deepEqual(report.findings, []);
  groups.forEach((names, layer) => names.forEach(name => assert.equal(report.modules.find(item => item.name === `Ark.${name}`).layer, layer)));
  assert.equal(report.modules.find(item => item.name === 'Ark.Math.Matrix').depth, 1);
  assert.equal(report.modules.find(item => item.name === 'Ark.Game.Scene').layer, 5);
  assert.deepEqual(analyze([...sources].reverse()), report);
});

test('peer/upward, reverse shared edges, unknown roots and missing imports are explicit', () => {
  const report = analyze([
    node('Ark.Core', ['Ark.Math']), node('Ark.Math', ['Ark.Render', 'Std.Utility']),
    node('Ark.Render'), node('Std.Utility', ['Ark.Game']), node('Ark.Game'),
    node('Ark.Unknown'), node('Ark'), node('Ark.Tools', ['Project.Helper', 'Std.Missing']), node('Project.Helper'),
  ]);
  assert.deepEqual(report.findings, [
    'missing import: Ark.Tools -> Std.Missing', 'non-library import: Ark.Tools -> Project.Helper',
    'reverse engine import: Std.Utility -> Ark.Game', 'unclassified engine module: Ark',
    'unclassified engine module: Ark.Unknown', 'upward engine import: Ark.Core [0] -> Ark.Math [0]',
    'upward engine import: Ark.Math [0] -> Ark.Render [3]',
  ]);
  assert(report.modules.find(item => item.name === 'Ark.Tools').imports.includes('Std.Missing'));
  assert.deepEqual(analyze([node('Arks.Math')]).findings, []);
});

test('cycles, duplicates and deep same-root graphs remain bounded and deterministic', () => {
  assert.deepEqual(analyze([node('Ark.Math', ['Ark.Math'])]).findings, ['import cycle: Ark.Math']);
  assert.deepEqual(analyze([node('Ark.Math.A', ['Ark.Math.B']), node('Ark.Math.B', ['Ark.Math.A'])]).findings,
    ['import cycle: Ark.Math.A, Ark.Math.B']);
  assert.throws(() => analyze([node('Ark.Math'), node('Ark.Math')]), /duplicate module: Ark.Math/);
  const chain = Array.from({length: 5000}, (_, index) => node(`Ark.Math.N${index}`, index ? [`Ark.Math.N${index - 1}`] : []));
  const report = analyze(chain);
  assert.deepEqual(report.findings, []);
  assert.equal(report.modules.find(item => item.name === 'Ark.Math.N4999').depth, 4999);
});

test('CLI checks actual and malformed source roots with exact findings', () => {
  const actual = run('--json');
  assert.equal(actual.status, 0, actual.stderr);
  assert.deepEqual(JSON.parse(actual.stdout).findings, []);
  const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-layers-'));
  try {
    assert.match(run('--root', scratch).stderr, /no Pudu module sources/);
    assert.notEqual(run('--root', join(scratch, 'absent')).status, 0);
    mkdirSync(join(scratch, 'Ark'));
    writeFileSync(join(scratch, 'Ark/Math.pudu'), 'module Ark.Math\nimport Ark.Game\n');
    writeFileSync(join(scratch, 'Ark/Game.pudu'), 'module Ark.Game\n');
    const rejected = run('--root', scratch);
    assert.equal(rejected.status, 1);
    assert.equal(rejected.stderr.trim(), 'upward engine import: Ark.Math [0] -> Ark.Game [5]');
    writeFileSync(join(scratch, 'Ark/Math.pudu'), 'module Ark.Math\n');
    assert.equal(run('--root', scratch).status, 0);
    writeFileSync(join(scratch, 'Ark/Math.pudu'), 'module Ark.Wrong\n');
    assert.match(run('--root', scratch).stderr, /module path mismatch: Ark.Wrong at Ark\/Math.pudu/);
    writeFileSync(join(scratch, 'Ark/Math.pudu'), 'not a module');
    assert.match(run('--root', scratch).stderr, /expected one module declaration/);
    assert.match(run('--unknown').stderr, /invalid argument: --unknown/);
  } finally { rmSync(scratch, {recursive: true, force: true}); }
});
