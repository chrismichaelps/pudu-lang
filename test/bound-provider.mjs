import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scratch = mkdtempSync(join(tmpdir(), 'pudu-bound-provider-'));
const path = join(scratch, 'Case.pudu');
const cache = join(scratch, 'cache');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const call = (command, mode = 'compiled', caching = 'off') => spawnSync(binary, [command, path], {
  env: {...env, PUDU_EVAL: mode, PUDU_CACHE: caching}, encoding: 'utf8', timeout: 60000,
});
const entries = () => readdirSync(cache, {recursive: true}).map(name => join(cache, name))
  .filter(name => statSync(name).isFile()).sort().map(name => [name, statSync(name).ino]);
try {
  for (const owner of ['Int', 'Box', 'Str']) for (const reversed of [false, true]) {
    const impls = [
      `impl TextWire for ${owner} { fn encode(self: &Self) -> Str { "text" } }`,
      `impl IntWire for ${owner} { fn encode(self: &Self) -> Int { 7 } }`,
    ];
    if (reversed) impls.reverse();
    const declarations = [
      'module Case', 'type Box = { value: Int }',
      'trait TextWire { fn encode(self: &Self) -> Str',
      '  fn wrapper(self: &Self) -> Str { self.encode() } }',
      'trait IntWire { fn encode(self: &Self) -> Int }', ...impls,
      'fn text[T: TextWire](value: &T) -> Str { value.encode() }',
      'fn number[T: IntWire](value: &T) -> Int { value.encode() }',
      'fn alias[T: TextWire](value: &T) -> Str {',
      '  let other = value', '  other.encode()', '}',
      'fn retained[A: TextWire, B: IntWire](a: &A, b: &B) -> Str {',
      '  let first = a.encode', '  let second = b.encode',
      '  if second() != 7 { panic("wrong retained provider") }', '  first()', '}',
      'fn defaults[T: TextWire](value: &T) -> Str { value.wrapper() }',
    ];
    const literal = owner === 'Int' ? '1' : owner === 'Str' ? '"receiver"' : 'Box{value: 1}';
    const main = [ 'export fn main() -> Int {', `  let value: ${owner} = ${literal}` ];
    writeFileSync(path, [...declarations, ...main,
      '  print(text(&value))', '  print(show(number(&value)))',
      '  print(alias(&value))', '  print(retained(&value, &value))',
      '  print(defaults(&value))', '  0', '}',
    ].join('\n') + '\n');
    for (const mode of ['tree', 'compiled']) {
      const run = caching => {
        const result = call('run', mode, caching);
        assert.equal(result.status, 0, result.stdout + result.stderr);
        assert.equal(result.stdout, 'text\n7\ntext\ntext\ntext\n');
      };
      run('off');
      run(cache);
      const stored = entries();
      assert(stored.length >= 2, 'frontend and checked products must be stored');
      run(cache);
      assert.deepEqual(entries(), stored, 'warm execution must reuse stored products');
    }
    for (const [extra, code] of [
      ['fn wrong[T: TextWire](value: &T) -> Int { value.encode() }', 'E3001'],
      ['fn wrong[T: TextWire + IntWire](value: &T) -> Str { value.encode() }', 'E3013'],
      ['fn wrong[T](value: &T) -> Str { text(value) }', 'E3012'],
    ]) {
      writeFileSync(path, [...declarations, extra, ...main, '  0', '}'].join('\n') + '\n');
      const result = call('check');
      assert.notEqual(result.status, 0, extra);
      assert.match(result.stdout + result.stderr, new RegExp(code));
      assert.match(result.stdout + result.stderr, /Case\.pudu:\d+:\d+/);
    }
  }
  for (const [parameters, target, alias, argument, expected] of [
    ['A: Named, B: Named', 'Pair[B, A]', '', 'Pair[Int, Str]', 'str/int'],
    ['A: Named', 'Array[Array[A]]', '', 'Array[Array[Int]]', 'nested int'],
    ['A: Named, B: Named', 'Reversed[A, B]', 'type Reversed[X, Y] = Pair[Y, X]', 'Pair[Int, Str]', 'str/int'],
    ['A: Named', 'Pair[A, A]', '', 'Pair[Int, Int]', 'int'],
  ]) {
    const label = target.startsWith('Array') ? '"nested " + A.label()'
      : parameters.includes('B:') ? 'A.label() + "/" + B.label()' : 'A.label()';
    const program = [
      'module Case', 'trait Named { fn label() -> Str',
      '  fn chosen[C: Named](value: &C) -> Str { C.label() }', '}',
      'impl Named for Int { fn label() -> Str { "int" } }',
      'impl Named for Str { fn label() -> Str { "str" } }',
      'type Pair[L, R] = { left: L, right: R }', alias,
      `impl[${parameters}] Named for ${target} {`,
      `  fn label() -> Str { ${label} }`,
      `  fn chosen[C: Named](value: &C) -> Str { ${label} + "/" + C.label() }`, '}',
      'fn selected[T: Named]() -> Str { T.label() }',
      'fn method[T: Named]() -> Str { T.chosen(&"str") }',
      'fn explicit[T: Named]() -> Str { T.chosen[Str](&"str") }',
      'fn retainedStatic[T: Named]() -> Str { let selected = T.chosen', '  selected(&"str")', '}',
      'export fn main() -> Int {', `  print(selected[${argument}]())`,
      `  print(method[${argument}]())`, `  print(explicit[${argument}]())`,
      `  print(retainedStatic[${argument}]())`, '  0', '}',
    ].filter(Boolean).join('\n') + '\n';
    writeFileSync(path, program);
    for (const mode of ['tree', 'compiled']) {
      const exact = caching => {
        const result = call('run', mode, caching);
        assert.equal(result.status, 0, `${target}: ${result.stdout}${result.stderr}`);
        assert.equal(result.stdout, `${expected}\n${expected}/str\n${expected}/str\n${expected}/str\n`, target);
      };
      exact('off');
      exact(cache);
      const stored = entries();
      exact(cache);
      assert.deepEqual(entries(), stored, 'matched witnesses must reuse warm products');
    }
      if (target === 'Pair[A, A]') {
      writeFileSync(path, program.replaceAll('Pair[Int, Int]', 'Pair[Int, Str]'));
      const refused = call('check');
      assert.notEqual(refused.status, 0);
      assert.match(refused.stdout + refused.stderr, /E3012/);
      assert.match(refused.stdout + refused.stderr, /Case\.pudu:\d+:\d+/);
    }
  }
  const qualifierHeader = [
    'module Case', 'trait Named { fn label() -> Str',
    '  fn chosen[C: Named](value: &C) -> Str { C.label() }', '}',
    'impl Named for Str { fn label() -> Str { "str" } }',
    'trait Other { fn label() -> Int }',
    'type Shadow = { chosen: fn(&Str) -> Str }',
  ];
  const shadow = ['fn shadow[T: Named]() -> Str {',
    '  const T = Shadow{chosen: fn(value: &Str) -> Str { "shadow" }}',
    '  T.chosen(&"str")', '}'];
  writeFileSync(path, [...qualifierHeader, ...shadow, 'export fn main() -> Int {',
    '  print(shadow[Str]())', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) for (const caching of ['off', cache, cache]) {
    const result = call('run', mode, caching);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stdout, 'shadow\n');
  }
  for (const [extra, code] of [
    ['fn wrong[T: Named]() -> Int { T.label() }', 'E3001'],
    ['fn wrong[T: Named]() -> Str { T.label(1) }', 'E3003'],
    ['fn wrong[T]() -> Str { T.label() }', 'E3005'],
    ['fn wrong[T: Named]() -> Str { T.chosen[Bool](&true) }', 'E3012'],
    ['fn wrong[T: Named + Other]() -> Str { T.label() }', 'E3013'],
    [shadow.join('\n').replace('T.chosen(&"str")', 'T.chosen[Str](&"str")'), 'E3028'],
  ]) {
    writeFileSync(path, [...qualifierHeader, extra, 'export fn main() -> Int { 0 }'].join('\n') + '\n');
    const result = call('check');
    assert.notEqual(result.status, 0, extra);
    assert.match(result.stdout + result.stderr, new RegExp(code));
    assert.match(result.stdout + result.stderr, /Case\.pudu:\d+:\d+/);
  }
  writeFileSync(join(scratch, 'TextOps.pudu'), [
    'module TextOps', 'export trait Wire { fn encode(self: &Self) -> Str }',
    'impl Wire for Int { fn encode(self: &Self) -> Str { "text" } }',
    'export fn text[T: Wire](value: &T) -> Str { value.encode() }',
  ].join('\n') + '\n');
  writeFileSync(join(scratch, 'NumberOps.pudu'), [
    'module NumberOps', 'export trait Wire { fn encode(self: &Self) -> Int }',
    'impl Wire for Int { fn encode(self: &Self) -> Int { 7 } }',
    'export fn number[T: Wire](value: &T) -> Int { value.encode() }',
  ].join('\n') + '\n');
  writeFileSync(path, [
    'module Case', 'import TextOps { text }', 'import NumberOps { number }',
    'export fn main() -> Int {', '  let value: Int = 1',
    '  print(text(&value))', '  print(show(number(&value)))', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) for (const caching of ['off', cache, cache]) {
    const result = call('run', mode, caching);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stdout, 'text\n7\n');
  }
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Bound providers preserve direct, retained, alias, default and cached execution');
