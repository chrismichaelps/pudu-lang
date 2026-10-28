import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const library = join(root, 'packages/pudu/v0.1/lib');
const env = {...process.env, PUDU_LIB: library};
const fixture = join(root, 'test-fixtures/ark/UsesArkRender.pudu');
const clipFixture = join(root, 'test-fixtures/ark/UsesArkClip.pudu');
const perspectiveFixture = join(root, 'test-fixtures/ark/UsesArkPerspective.pudu');
const texturedFixture = join(root, 'test-fixtures/ark/UsesArkTextured.pudu');
const demo = join(root, 'examples/ark/SpinningCubes.pudu');
const modules = ['Device', 'Mesh', 'Pipeline', 'Clip', 'Graph'].map(name => `Ark/Render/${name}.pudu`);
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 300000});
assert.equal(run('run', fixture), 'ark render: ok\n');
assert.equal(run('run', clipFixture), 'ark depth clip: ok\n');
assert.equal(run('run', perspectiveFixture), 'ark perspective: ok\n');
assert.equal(run('run', texturedFixture), 'ark textured: ok\n');
run('fmt', '--check', fixture, clipFixture, perspectiveFixture, texturedFixture, demo, ...modules.map(path => join(library, path)));
run('check', demo);
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-render-'));
try {
  const image = join(scratch, 'frame.ppm');
  const report = run('run', demo, '--snapshot', image);
  assert.match(report, /^wrote .* in \d+ us\n$/);
  const bytes = readFileSync(image);
  const header = 'P6\n640 480\n255\n';
  assert.equal(bytes.subarray(0, header.length).toString('latin1'), header);
  assert.equal(bytes.length, header.length + 640 * 480 * 3);
  const pixels = bytes.subarray(header.length);
  const at = (x, y) => Array.from(pixels.subarray((y * 640 + x) * 3, (y * 640 + x) * 3 + 3));
  assert.deepEqual(at(2, 2), [13, 15, 23], 'background in the top-left corner');
  let drawn = 0;
  for (let i = 0; i < pixels.length; i += 3) {
    if (pixels[i] !== 13 || pixels[i + 1] !== 15 || pixels[i + 2] !== 23) drawn++;
  }
  assert(drawn > 640 * 480 * 0.2, `scene covers too little of the frame: ${drawn}`);
  const typed = join(scratch, 'MeshAsBatch.pudu');
  writeFileSync(typed, 'module MeshAsBatch\nimport Ark.Math.Color as Color\nimport Ark.Render.Device as Device\nimport Ark.Render.Mesh as Mesh\nexport fn main() -> Int {\n  let Some(surface) = Device.target(4, 4) else { return 1 }\n  let drawn = Device.draw(surface, &Mesh.cube(Color.opaque(1.0, 1.0, 1.0)), Device.CullBack)\n  if drawn == None { 1 } else { 0 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /MeshAsBatch\.pudu:7:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
  console.log(report.trim());
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Ark render device, pipeline, texturing, frame graph, demo snapshot, refusals and distribution passed');
