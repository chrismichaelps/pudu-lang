import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {test} from 'node:test';
import {buildGraph, joinProfile, parseHaskell, parseProfile} from './layers/model.mjs';
import {renderReport} from './layers/view.mjs';

const source = (name, imports = []) => ({name, imports, path: `${name}.hs`, lines: 1});
const ticky = `Entries Alloc Alloc'd Non-void Arguments STG Name
--------------------------------------------------------------------------------
  7  100  9000  1 M       Pudu.Eval.work{v r1} (fun)
  3  200  8000  0         go{v r2} (Pudu.Type) (fun)
  0  0    3000  0         mystery{v} (fun)
ALLOC_HEAP_ctr 20000
`;
const prof = `total time = 0.50 secs (50 ticks)
total alloc = 10,000 bytes (excludes profiling overheads)
COST CENTRE MODULE SRC %time %alloc
work Pudu.Eval X.hs:1 60.0 70.0

                         individual inherited
COST CENTRE MODULE SRC no. entries %time %alloc %time %alloc
MAIN MAIN <built-in> 1 0 0.0 0.0 100.0 100.0
 work Pudu.Eval X.hs:1 2 7 20.0 30.0 90.0 90.0
  child Pudu.Type Y.hs:1 3 3 60.0 50.0 60.0 50.0
 work Pudu.Eval X.hs:1 4 2 20.0 20.0 20.0 20.0
`;

test('source scanner ignores nested comments, strings and character literals', () => {
  const node = parseHaskell(`{-# LANGUAGE PackageImports #-}
module Pudu.Example where
{- outer {- import Fake.Inner -} import Fake.Outer -}
-- import Fake.Line
import {-# SOURCE #-} qualified Pudu.Base
import safe "package-name" Pudu.Safe qualified as S
import
 qualified
 Pudu.Multiline
value = "hello\\\"\nimport Fake.String"
tick = '\"'
`, 'Example.hs');
  assert.equal(node.name, 'Pudu.Example');
  assert.deepEqual(node.imports, ['Pudu.Base', 'Pudu.Multiline', 'Pudu.Safe']);
  assert.throws(() => parseHaskell('module Pudu.X where\n{-', 'bad.hs'), /unterminated/);
  assert.throws(() => parseHaskell('value = 1', 'bad.hs'), /missing module/);
});

test('diamond layers and actual SCC cycles have independent graph oracles', () => {
  const graph = buildGraph([source('A', ['B', 'C', 'Outside']), source('B', ['D']), source('C', ['D']),
    source('D'), source('X', ['Y']), source('Y', ['X', 'D']), source('Self', ['Self'])]);
  const nodes = new Map(graph.nodes.map(n => [n.name, n]));
  assert.deepEqual(['D', 'B', 'C', 'A'].map(n => nodes.get(n).layer), [0, 1, 1, 2]);
  assert.deepEqual(nodes.get('A').external, ['Outside']);
  assert.deepEqual(nodes.get('D').importers, ['B', 'C', 'Y']);
  assert.deepEqual(graph.components.filter(c => c.cyclic).map(c => c.members).sort(), [['Self'], ['X', 'Y']]);
  assert.equal(nodes.get('X').layer, 1);
  assert.deepEqual(buildGraph([...graph.nodes].reverse()).components, graph.components);
  assert.throws(() => buildGraph([source('A'), source('A')]), /duplicate module/);
});

test('long dependency chains do not consume the JavaScript call stack', () => {
  const count = 6000;
  const graph = buildGraph(Array.from({length: count}, (_, i) => source(`M${i}`, i ? [`M${i - 1}`] : [])));
  assert.equal(graph.nodes.find(n => n.name === 'M5999').layer, count - 1);
  assert.equal(graph.components.length, count);
  assert.equal(new Set(graph.components.flatMap(c => c.members)).size, count);
});

test('ticky attributes allocations by closures, never Alloc\u0027d', () => {
  const profile = parseProfile(ticky);
  assert.equal(profile.kind, 'ticky');
  assert.deepEqual(profile.rows.map(r => [r.module, r.allocBytes, r.cpuMs, r.entries]),
    [['Pudu.Eval', 100, null, 7], ['Pudu.Type', 200, null, 3], ['(unattributed)', 0, null, 0]]);
  assert.throws(() => parseProfile(ticky.replace('100', '9007199254740992')), /invalid profile number/);
  assert.throws(() => parseProfile(ticky.replace('7  100', '7  nope')), /malformed/);
});

test('cost-centre trees use individual costs and ignore duplicate flat/inherited costs', () => {
  const profile = parseProfile(prof);
  const report = joinProfile(buildGraph([source('Pudu.Eval'), source('Pudu.Type'), source('Pudu.Unmeasured')]), profile);
  const evalNode = report.nodes.find(n => n.name === 'Pudu.Eval');
  assert.deepEqual(evalNode.costs, {allocBytes: 5000, cpuMs: 200, entries: 9});
  assert.deepEqual(report.profile.attributed, {allocBytes: 10000, cpuMs: 500, entries: 12});
  assert.deepEqual(report.nodes.find(n => n.name === 'Pudu.Unmeasured').costs,
    {allocBytes: null, cpuMs: null, entries: null});
  assert.equal(report.unmatched[0].name, 'MAIN');
});

test('old profiles without SRC and flat subsets retain explicit coverage', () => {
  const old = prof.replaceAll(' SRC', '').replaceAll(' X.hs:1', '').replaceAll(' Y.hs:1', '').replaceAll(' <built-in>', '');
  assert.equal(parseProfile(old).rows[1].allocBytes, 3000);
  const flat = parseProfile(prof.slice(0, prof.indexOf('                         individual')));
  assert.match(flat.coverage, /subset/);
  assert.equal(flat.rows[0].entries, null);
  assert.throws(() => parseProfile('some arbitrary text'), /unsupported profile/);
  assert.throws(() => parseProfile(prof.replace('total alloc', 'missing alloc')), /lacks total/);
});

test('joins preserve unmatched attribution and unknown measures without losing totals', () => {
  const report = joinProfile(buildGraph([source('Pudu.Eval')]), parseProfile(ticky));
  assert.equal(report.profile.attributed.allocBytes, 100);
  assert.equal(report.profile.unmatched.allocBytes, 200);
  assert.equal(report.profile.attributed.cpuMs, null);
  assert.equal(report.unmatched.length, 2);
  assert.equal(joinProfile(buildGraph([source('A')]), null).nodes[0].measured, false);
});

test('embedded report data cannot inject HTML or executable script', () => {
  const hostile = '</script><script>alert(1)</script><img src=x onerror=alert(1)>';
  const report = joinProfile(buildGraph([source('Pudu.Eval')]), null, {label: hostile});
  const html = renderReport(report);
  const embedded = html.match(/<script id="data" type="application\/json">(.*?)<\/script>/s)[1];
  assert.equal(JSON.parse(embedded).provenance.label, hostile);
  assert.ok(!html.includes(hostile));
  assert.equal([...html.matchAll(/<script\b/g)].length, 2);
  assert.ok(!html.includes('innerHTML'));
});

test('CLI emits offline HTML/JSON and refuses invalid inputs or input replacement', async () => {
  const root = await mkdtemp(join(tmpdir(), 'pudu-layers-test-'));
  const cli = resolve('bench/layers.mjs');
  const run = args => spawnSync(process.execPath, [cli, '--root', root, ...args], {encoding: 'utf8'});
  try {
    const input = join(root, 'A.hs'), profile = join(root, 'run.ticky');
    await writeFile(input, 'module A where\nimport Pudu.Eval\n');
    await writeFile(profile, ticky);
    const output = join(root, 'report.html');
    const good = run(['--profile', profile, '--out', output]);
    assert.equal(good.status, 0, good.stderr);
    const json = JSON.parse(await readFile(`${output}.json`, 'utf8'));
    assert.equal(json.nodes.length, 1);
    assert.equal(json.provenance.profileHash.length, 64);
    assert.match(await readFile(output, 'utf8'), /Dependency layer treemap/);
    assert.match(run(['--unknown', 'x']).stderr, /unknown option/);
    assert.match(run(['--profile', profile, '--out', input]).stderr, /overwrite/);
    assert.match(run(['--profile', profile, '--out', profile]).stderr, /overwrite/);
    assert.match(run(['--profile']).stderr, /missing value/);
    assert.equal(await readFile(input, 'utf8'), 'module A where\nimport Pudu.Eval\n');
    assert.equal(await readFile(profile, 'utf8'), ticky);
    await writeFile(profile, 'not a profile');
    assert.equal(run(['--profile', profile, '--out', output]).status, 1);
  } finally { await rm(root, {recursive: true, force: true}); }
});
