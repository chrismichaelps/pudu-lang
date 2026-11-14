import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = readFileSync(join(root, 'examples/ark/WaveTank.pudu'), 'utf8');
const entry = 'export fn main() -> Int {';
assert.equal(source.split(entry).length, 2, 'expected one demo entry point');
for (const declaration of ['const CELLS: Int = 56', 'const COURANT: Float64 = 0.3',
  'const DAMPING: Float64 = 0.996', 'const DROP_EVERY: Int = 45']) {
  assert.equal(source.split(declaration + '\n').length, 2, `review adapter: ${declaration}`);
}
const digest = createHash('sha256').update(source).digest('hex');
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-water-'));
const path = join(scratch, 'WaveTank.pudu');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
// Closed-form modes of the reflecting discrete Laplacian, independent of the lane update.
const modalFactor = (p, r, n) => {
  const eigenvalue = -4 * (Math.sin(Math.PI * p / 112) ** 2 + Math.sin(Math.PI * r / 112) ** 2);
  const d = 0.996, alpha = 1 + d + 0.3 * eigenvalue, rho = Math.sqrt(d);
  const theta = Math.acos(alpha / (2 * rho));
  const b = ((alpha - d) / rho - Math.cos(theta)) / Math.sin(theta);
  return rho ** n * (Math.cos(n * theta) + b * Math.sin(n * theta));
};
const modes = [[1, 0, 1], [1, 0, 63], [3, 2, 63], [55, 55, 63]];
const names = ['zero', 'constant', ...modes.map(([p, r, n]) => `mode-${p}-${r}-${n}`), 'superposition', 'mean'];
const program = `
fn waterInitial(base: Scene, height: Lanes.Lanes) -> Scene {
  Scene{..base, height, previous: height, steps: 0}
}
fn waterEvolve(initial: Scene, count: Int) -> Scene {
  var state = initial
  for _ in 0..count {
    state = advance(Scene{..state, steps: 0})
    let absolute = Lanes.abs(&state.height)
    let Some(peak) = Lanes.largest(&absolute) else { panic("empty wave") }
    if !Float.isFinite(Lanes.sum(&absolute)) || peak >= 0.01 { panic("wave escaped linear range") }
  }
  state
}
fn waterMode(p: Int, r: Int) -> Lanes.Lanes {
  var values: Array[Float64] = []
  for row in 0..CELLS {
    for column in 0..CELLS {
      let x = Float.pi() * Float.fromInt(p) * (Float.fromInt(column) + 0.5) / Float.fromInt(CELLS)
      let z = Float.pi() * Float.fromInt(r) * (Float.fromInt(row) + 0.5) / Float.fromInt(CELLS)
      values = values.push(0.0001 * Float.cos(x) * Float.cos(z))
    }
  }
  Lanes.fromArray(&values)
}
fn waterCompare(name: Str, actual: &Lanes.Lanes, expected: &Lanes.Lanes) -> () {
  let Some(delta) = Lanes.subtract(actual, expected) else { panic("wave dimensions") }
  var error = 0.0
  for value in Lanes.toArray(&delta) {
    if !Float.isFinite(value) { panic("nonfinite wave error") }
    let magnitude = Float.abs(value)
    if magnitude > error { error = magnitude }
  }
  if error > 0.0000000001 { panic(name + " error " + show(error)) }
  print(name + " " + show(error))
  ()
}
export fn main() -> Int {
  let base = setup()
  let Some(zero) = Lanes.filled(CELLS * CELLS, 0.0) else { panic("zero grid") }
  let Some(constant) = Lanes.filled(CELLS * CELLS, 0.0009765625) else { panic("constant grid") }
  waterCompare("zero", &waterEvolve(waterInitial(base, zero), 120).height, &zero)
  waterCompare("constant", &waterEvolve(waterInitial(base, constant), 120).height, &constant)
${modes.map(([p, r, n], i) => `  let mode${i} = waterMode(${p}, ${r})
  waterCompare("mode-${p}-${r}-${n}", &waterEvolve(waterInitial(base, mode${i}), ${n}).height, &Lanes.scale(&mode${i}, ${modalFactor(p, r, n).toExponential(17)}))`).join('\n')}
  let first = waterMode(2, 1)
  let second = waterMode(4, 3)
  let Some(combined) = Lanes.add(&first, &second) else { panic("combine") }
  let a = waterEvolve(waterInitial(base, first), 63)
  let b = waterEvolve(waterInitial(base, second), 63)
  let Some(expected) = Lanes.add(&a.height, &b.height) else { panic("superposition") }
  waterCompare("superposition", &waterEvolve(waterInitial(base, combined), 63).height, &expected)
  let bumped = drop(waterInitial(base, zero), CELLS / 2, CELLS / 3, 0.001)
  let moved = waterEvolve(waterInitial(base, bumped.height), 90)
  let error = Float.abs(Lanes.sum(&moved.height) - Lanes.sum(&bumped.height))
  if !Float.isFinite(error) || error > 0.0000000001 { panic("mean displacement") }
  print("mean " + show(error))
  0
}
`;
const inventory = cache => readdirSync(cache, {recursive: true}).map(name => join(cache, name))
  .filter(name => statSync(name).isFile()).sort().map(name => [name, statSync(name).ino]);
try {
  writeFileSync(path, source.replace(entry, 'fn waterDemoEntry() -> Int {') + program);
  let maximum = 0;
  for (const mode of ['tree', 'compiled']) {
    const cache = join(scratch, 'cache-' + mode);
    let stored;
    for (const [index, caching] of ['off', cache, cache].entries()) {
      const result = spawnSync(binary, ['run', path], {
        env: {...env, PUDU_EVAL: mode, PUDU_CACHE: caching}, encoding: 'utf8', timeout: 300000,
      });
      assert.equal(result.status, 0, `${mode}/${index}: ${result.error ?? ''}\n${result.stdout}\n${result.stderr}`);
      const lines = result.stdout.trim().split('\n');
      assert.equal(lines.length, names.length, result.stdout);
      lines.forEach((line, i) => {
        const [name, raw, extra] = line.split(' ');
        const error = Number(raw);
        assert.equal(name, names[i]);
        assert.equal(extra, undefined);
        assert(raw && Number.isFinite(error) && error >= 0 && error <= 1e-10, line);
        maximum = Math.max(maximum, error);
      });
      if (index === 1) { stored = inventory(cache); assert(stored.length >= 2, 'cache products absent'); }
      if (index === 2) assert.deepEqual(inventory(cache), stored, 'warm run rewrote cache products');
    }
  }
  console.log(`Ark water: ${names.length} cases x 6 evaluator/cache runs; maximum error ${maximum}; source sha256 ${digest}`);
} finally { rmSync(scratch, {recursive: true, force: true}); }
