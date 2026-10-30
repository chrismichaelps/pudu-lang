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
const modulePath = 'Ark/Assets/Texture.pudu';
const fixture = join(root, 'test-fixtures/ark/UsesArkTexture.pudu');
const graphFixture = join(root, 'test-fixtures/ark/UsesArkAssetGraph.pudu');
const serverFixture = join(root, 'test-fixtures/ark/UsesArkAssetServer.pudu');
const streamFixture = join(root, 'test-fixtures/ark/UsesArkStream.pudu');
const shipped = ['Texture', 'Graph', 'Import', 'Server', 'Stream'].map(name => `Ark/Assets/${name}.pudu`);
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 60000});
assert.equal(run('run', fixture), 'ark texture: ok\n');
assert.equal(run('run', graphFixture), 'ark asset graph: ok\n');
assert.equal(run('run', serverFixture), 'ark asset server: ok\n');
assert.equal(run('run', streamFixture), 'ark stream: ok\n');
run('fmt', '--check', fixture, graphFixture, serverFixture, streamFixture, ...shipped.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-assets-'));
try {
  const refused = join(scratch, 'InvalidUv.pudu');
  writeFileSync(refused, 'module InvalidUv\nimport Ark.Assets.Texture as Texture\nexport fn main() -> Int {\n  let Some(image) = Texture.rgba8(1, 1, bytesOf([0, 0, 0, 255]), "linear") else { return 1 }\n  let color = Texture.nearest(&image, "left", 0.5)\n  if color == None { 1 } else { 0 }\n}\n');
  const checked = spawnSync(binary, ['check', refused], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /InvalidUv\.pudu:5:/);
  const budget = join(scratch, 'BudgetAsText.pudu');
  writeFileSync(budget, 'module BudgetAsText\nimport Ark.Assets.Stream as Stream\nexport fn main() -> Int {\n  let budget = Stream.Budget{workers: "four", commits: 1}\n  0\n}\n');
  const typed = spawnSync(binary, ['check', budget], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(typed.status, 0);
  assert.match(typed.stdout + typed.stderr, /E3001/);
  assert.match(typed.stdout + typed.stderr, /BudgetAsText\.pudu:4:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of shipped) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Ark asset dependency order, staged reload, streaming, importers, texture sampling, color/alpha boundaries, diagnostics and shipping passed');
