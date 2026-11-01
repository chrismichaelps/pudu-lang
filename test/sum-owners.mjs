import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scratch = mkdtempSync(join(tmpdir(), 'pudu-sum-owner-'));
const file = join(scratch, 'Main.pudu');
const cache = join(scratch, 'cache');
const call = (command, mode = 'compiled', caching = 'off') => spawnSync(binary, [command, file], {
  env: {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib'), PUDU_EVAL: mode, PUDU_CACHE: caching},
  encoding: 'utf8', timeout: 60000,
});
const entries = () => readdirSync(cache, {recursive: true}).map(name => join(cache, name))
  .filter(name => statSync(name).isFile()).sort().map(name => [name, statSync(name).ino]);
const run = (expected, mode, caching = 'off') => {
  const result = call('run', mode, caching);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(result.stdout, expected);
};
try {
  writeFileSync(join(scratch, 'Contract.pudu'), 'module Contract\nexport trait Label { fn label(self: &Self) -> Str }\n');
  for (const [name, label] of [['First', 'first'], ['Second', 'second']]) {
    writeFileSync(join(scratch, `${name}.pudu`), [
      `module ${name}`, 'import Contract { Label }', 'export type Item = Empty | Chosen(Int)',
      `const NAME: Str = "${label}"`, 'const INSTANCE: Item = Chosen(1)',
      'impl Label for Item { fn label(self: &Self) -> Str { NAME } }',
      'export fn make() -> Item { Chosen(1) }', 'export fn frozen() -> Item { INSTANCE }',
    ].join('\n') + '\n');
  }
  for (const reversed of [false, true]) {
    const imports = ['import First as A', 'import Second as B'];
    if (reversed) imports.reverse();
    const header = ['module Main', 'import Contract { Label }', ...imports,
      'fn generic[T: Label](value: &T) -> Str { value.label() }',
      'fn same(a: dynamic Label, b: dynamic Label) -> Bool { a == b }'];
    const main = ['export fn main() -> Int {', '  let a = A.make()', '  let b = B.make()'];
    writeFileSync(file, [...header, ...main, '  if same(a, b) { panic("erased sum identity") }', '  print(a.label())', '  print(b.label())',
      '  print(generic(&a))', '  print(generic(&b))', '  let f = a.label', '  let s = b.label',
      '  print(f())', '  print(s())', '  let fa = A.frozen()', '  let fb = B.frozen()',
      '  print(generic(&fa))', '  print(generic(&fb))', '  print(show(a))',
      '  match a {', '    case A.Item.Chosen(value) => print(show(value))',
      '    case A.Item.Empty => print("empty")', '  }', '  0', '}',
    ].join('\n') + '\n');
    for (const mode of ['tree', 'compiled']) {
      run('first\nsecond\n'.repeat(4) + 'Chosen(1)\n1\n', mode);
      run('first\nsecond\n'.repeat(4) + 'Chosen(1)\n1\n', mode, cache);
      const stored = entries();
      assert(stored.length >= 8);
      run('first\nsecond\n'.repeat(4) + 'Chosen(1)\n1\n', mode, cache);
      assert.deepEqual(entries(), stored, 'warm products must retain sum owners');
    }
    writeFileSync(file, [...header, ...main, '  let wrong: A.Item = b', '  0', '}'].join('\n') + '\n');
    const bad = call('check');
    assert.notEqual(bad.status, 0);
    assert.match(bad.stdout + bad.stderr, /E3001/);
    assert.match(bad.stdout + bad.stderr, /Main\.pudu:\d+:\d+/);
    const narrowing = [...header,
      'fn inspect(value: dynamic Label) -> Str {', '  match value {',
      '    case A.Item.Chosen(99) => "partial"',
      '    case A.Item.Chosen(_) if false => "guarded"',
      '    case A.Item.Chosen(_) => "first"', '    case B.Item.Chosen(_) => "second"',
      '    case A.Item.Empty => "first empty"', '    case B.Item.Empty => "second empty"',
      '    case _ => "other"', '  }', '}',
      'fn conditional(value: dynamic Label) -> Str {',
      '  if let A.Item.Chosen(_) = value { "first" } else { "other" }', '}',
      'fn fallback(value: dynamic Label) -> Str {',
      '  let A.Item.Chosen(_) = value else { return "other" }', '  "first"', '}',
      'fn nested(value: Option[dynamic Label]) -> Str {', '  match value {',
      '    case Some(A.Item.Chosen(_)) => "nested first"',
      '    case Some(B.Item.Chosen(_)) => "nested second"',
      '    case _ => "other"', '  }', '}',
      ...main, '  print(inspect(a))', '  print(inspect(b))',
      '  print(inspect(A.Item.Empty))', '  print(inspect(B.Item.Empty))',
      '  print(conditional(a))', '  print(conditional(b))',
      '  print(fallback(a))', '  print(fallback(b))',
      '  print(nested(Some(a)))', '  print(nested(Some(b)))', '  0', '}',
    ];
    writeFileSync(file, narrowing.join('\n') + '\n');
    const checked = call('check');
    assert.equal(checked.status, 0, checked.stdout + checked.stderr);
    assert.doesNotMatch(checked.stdout + checked.stderr, /W5001/);
    const narrowed = 'first\nsecond\nfirst empty\nsecond empty\nfirst\nother\nfirst\nother\nnested first\nnested second\n';
    for (const mode of ['tree', 'compiled']) {
      run(narrowed, mode);
      run(narrowed, mode, cache);
      const stored = entries();
      run(narrowed, mode, cache);
      assert.deepEqual(entries(), stored, 'warm patterns must retain canonical owners');
    }
    writeFileSync(file, ['module Main', ...imports, 'import First as Again',
      'import Contract { Label }', 'fn repeated(value: dynamic Label) -> Str {',
      '  match value {', '    case A.Item.Chosen(_) | A.Item.Empty => "first"',
      '    case Again.Item.Chosen(_) => "repeated"', '    case _ => "other"', '  }', '}',
      'export fn main() -> Int {', '  print(repeated(A.make()))', '  0', '}',
    ].join('\n') + '\n');
    const repeated = call('check');
    assert.equal(repeated.status, 0, repeated.stdout + repeated.stderr);
    assert.equal((repeated.stdout + repeated.stderr).match(/W5001/g)?.length, 1,
      'aliases of one constructor must retain the repeated-arm warning');
  }
  writeFileSync(file, [
    'module Main', 'type MaybeValue = None | Some(Int)', 'type Choice = Ok(Int) | Err(Str)',
    'trait Pick { fn pick(self: &Self) -> Str }',
    'impl[T] Pick for Option[T] { fn pick(self: &Self) -> Str { "core" } }',
    'impl Pick for MaybeValue { fn pick(self: &Self) -> Str { "custom" } }',
    'fn generic[T: Pick](value: &T) -> Str { value.pick() }',
    'async fn kept() -> Choice { Ok(7) }', 'async fn failed() -> Choice { Err("kept") }',
    'export async fn main() -> Int {', '  let native = jsonDecode("1")', '  let custom = Some(9)',
    '  print(generic(&native))', '  print(generic(&custom))',
    '  print(show(kept().await))', '  print(show(failed().await))', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) run('core\ncustom\nOk(7)\nErr("kept")\n', mode);
  writeFileSync(file, [
    'module Main', 'import Std.Json as Json', 'export fn main() -> Int {',
    '  let Some(value) = jsonDecode("\\\"x\\\"") else { panic("native JSON") }',
    '  if value != Json.Text("x") { panic("JSON owner") }',
    '  print("native owner agrees")', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) run('native owner agrees\n', mode);
  writeFileSync(join(scratch, 'First.pudu'), [
    'module First', 'import Contract { Label }', 'export type Item[T] = Empty | Chosen{first: T}',
    'impl[T] Label for Item[T] { fn label(self: &Self) -> Str { "first" } }',
    'const INSTANCE: Item[Int] = Chosen{first: 1}',
    'export fn make() -> Item[Int] { Chosen{first: 1} }',
    'export fn frozen() -> Item[Int] { INSTANCE }',
  ].join('\n') + '\n');
  writeFileSync(join(scratch, 'Second.pudu'), [
    'module Second', 'import Contract { Label }', 'export type Item = Empty | Chosen{second: Str}',
    'impl Label for Item { fn label(self: &Self) -> Str { "second" } }',
    'const INSTANCE: Item = Chosen{second: "two"}',
    'export fn make() -> Item { Chosen{second: "two"} }',
    'export fn frozen() -> Item { INSTANCE }',
  ].join('\n') + '\n');
  writeFileSync(join(scratch, 'Third.pudu'), [
    'module Third', 'export type Item = Empty | Chosen(Int)',
    'export fn make() -> Item { Chosen(3) }',
  ].join('\n') + '\n');
  for (const reversed of [false, true]) {
    const imports = ['import First as A', 'import Second as B', 'import Third as C'];
    if (reversed) imports.reverse();
    const header = ['module Main', ...imports, 'export fn main() -> Int {'];
    const body = [
      '  let a = A.make()', '  let b = B.make()',
      '  match a {', '    case A.Item.Chosen{first} => print(show(first + 1))',
      '    case A.Item.Empty => print("empty")', '  }',
      '  match b {', '    case B.Item.Chosen{second} => print(second)',
      '    case B.Item.Empty => print("empty")', '  }',
      '  let direct: A.Item[Int] = A.Item.Chosen{first: 4}',
      '  let directB: B.Item = B.Item.Chosen{second: "five"}',
      '  if let A.Item.Chosen{first} = direct { print(show(first)) }',
      '  let B.Item.Chosen{second} = directB else { panic("named fields") }',
      '  print(second)', '  let positional = C.Item.Chosen(6)',
      '  match positional {', '    case C.Item.Chosen(value) => print(show(value))',
      '    case C.Item.Empty => print("empty")', '  }',
    ];
    writeFileSync(file, [...header, ...body, '  0', '}'].join('\n') + '\n');
    const accepted = call('check');
    assert.equal(accepted.status, 0, accepted.stdout + accepted.stderr);
    for (const mode of ['tree', 'compiled']) {
      run('2\ntwo\n4\nfive\n6\n', mode);
      run('2\ntwo\n4\nfive\n6\n', mode, cache);
      const stored = entries();
      run('2\ntwo\n4\nfive\n6\n', mode, cache);
      assert.deepEqual(entries(), stored, 'warm products preserve named field shapes');
    }
    const runtime = ['module Main', ...imports, 'import Contract { Label }',
      'type Holder = { mut item: A.Item[Int] }',
      'fn reset(value: &mut A.Item[Int]) -> () { *value = A.Item.Chosen{first: 8} }',
      'fn generic[T: Label](value: &T) -> Str { value.label() }',
      'fn inspect(value: dynamic Label) -> Str {', '  match value {',
      '    case A.Item.Chosen{first: 99} => "partial"',
      '    case A.Item.Chosen{first} if false => "guarded"',
      '    case A.Item.Chosen{..} => "first"',
      '    case B.Item.Chosen{..} => "second"', '    case _ => "other"', '  }', '}',
      'fn borrowed(value: &A.Item[Int]) -> Int {', '  match value {',
      '    case A.Item.Chosen{first} => first', '    case A.Item.Empty => 0', '  }', '}',
      'export fn main() -> Int {', '  let a = A.make()', '  let b = B.make()',
      '  print(a.label())', '  print(b.label())',
      '  print(generic(&a))', '  print(generic(&b))',
      '  let first = a.label', '  let second = b.label', '  print(first())', '  print(second())',
      '  print(generic(&A.frozen()))', '  print(generic(&B.frozen()))',
      '  print(show(borrowed(&a)))', '  print(inspect(a))', '  print(inspect(b))',
      '  var holder = Holder{item: A.make()}', '  reset(&mut holder.item)',
      '  print(show(borrowed(&holder.item)))', '  0', '}',
    ];
    writeFileSync(file, runtime.join('\n') + '\n');
    for (const mode of ['tree', 'compiled']) {
      const expected = 'first\nsecond\n'.repeat(4) + '1\nfirst\nsecond\n8\n';
      run(expected, mode);
      run(expected, mode, cache);
      const stored = entries();
      run(expected, mode, cache);
      assert.deepEqual(entries(), stored, 'warm named values retain owners and patterns');
    }
    for (const [line, code] of [
      ['  let wrong = A.Item.Chosen{second: "wrong"}', 'E3005'],
      ['  let missing = B.Item.Chosen{}', 'E3008'],
      ['  let wrong = B.Item.Chosen{second: 1}', 'E3001'],
      ['  let called = A.Item.Chosen(1)', 'E3034'],
      ['  let retained = B.Item.Chosen', 'E3034'],
      ['  let exported = A.Chosen(1)', 'E3034'],
    ]) {
      writeFileSync(file, [...header, line, '  0', '}'].join('\n') + '\n');
      const rejected = call('check');
      assert.notEqual(rejected.status, 0, rejected.stdout + rejected.stderr);
      const diagnostics = rejected.stdout + rejected.stderr;
      assert.match(diagnostics, new RegExp(code));
      assert.match(diagnostics, /Main\.pudu:\d+:\d+/);
      if (code === 'E3034') assert.equal(diagnostics.match(/E3034/g)?.length, 1);
    }
  }
  writeFileSync(file, ['module Main', 'type Parts = Empty | Chosen{first: Int, second: Int}',
    'fn mark(value: Int) -> Int {', '  print(show(value))', '  value', '}',
    'fn closed(value: Int) -> Parts { Chosen{second: value + 1, first: value} }',
    'fn ordered(value: Int) -> Parts { Chosen{first: value, second: value + 1} }',
    'export fn main() -> Int {',
    '  let a = Chosen{second: mark(2), first: mark(1)}',
    '  let b = Chosen{first: 1, second: 2}', '  print(show(a))',
    '  if a != b { panic("named field storage order") }',
    '  var digits = 0', '  for part in a { digits = digits * 10 + part }', '  print(show(digits))',
    '  var turn = 0', '  var total = 0',
    '  while turn < 3 && closed(turn) == ordered(turn) {',
    '    total = total + turn', '    turn = turn + 1', '  }', '  print(show(total))',
    '  turn = 0', '  total = 0', '  while turn < 3 {',
    '    match closed(turn) {', '      case Chosen{first, second} => total = total + first + second',
    '      case Empty => {}', '    }', '    turn = turn + 1', '  }', '  print(show(total))', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) run('2\n1\nChosen{first: 1, second: 2}\n12\n3\n9\n', mode);
  writeFileSync(file, ['module Main', 'type Answer = Ok{value: Int} | Err{message: Str}',
    'async fn kept() -> Answer { Ok{value: 7} }', 'async fn failed() -> Answer { Err{message: "kept"} }',
    'export async fn main() -> Int {', '  print(show(kept().await))', '  print(show(failed().await))', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) run('Ok{value: 7}\nErr{message: "kept"}\n', mode);
  const emptyHeader = ['module Main', 'type Choice = Absent | Chosen{}',
    'export fn main() -> Int {', '  let value = Chosen{}', '  match value {'];
  writeFileSync(file, [...emptyHeader, '    case Chosen{} => 0', '    case Absent => 1', '  }', '}'].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) run('', mode);
  writeFileSync(file, [...emptyHeader, '    case Chosen() => 0', '    case Absent => 1', '  }', '}'].join('\n') + '\n');
  const emptyPattern = call('check');
  assert.notEqual(emptyPattern.status, 0);
  assert.match(emptyPattern.stdout + emptyPattern.stderr, /E3034/);
  assert.match(emptyPattern.stdout + emptyPattern.stderr, /Main\.pudu:6:10/);
  const localTypes = ['type One = Empty | Chosen(Int)', 'type Two = Empty | Chosen(Int)',
    'type NamedOne = Vacant | Held{value: Int}', 'type NamedTwo = Vacant | Held{value: Int}',
    'type FlagOne = Off | On', 'type FlagTwo = Off | On'];
  for (const reversed of [false, true]) {
    const declarations = reversed ? [...localTypes].reverse() : localTypes;
    const localHeader = ['module Main', ...declarations,
      'trait Label { fn label(self: &Self) -> Str }',
      ...[['One', 'one'], ['Two', 'two'], ['NamedOne', 'named one'], ['NamedTwo', 'named two']]
        .map(([owner, label]) => `impl Label for ${owner} { fn label(self: &Self) -> Str { "${label}" } }`),
      'fn generic[T: Label](value: &T) -> Str { value.label() }',
      'fn inspect(value: dynamic Label) -> Str {', '  match value {',
      '    case One.Chosen(_) => "one"', '    case Two.Chosen(_) => "two"',
      '    case NamedOne.Held{..} => "named one"', '    case NamedTwo.Held{..} => "named two"',
      '    case _ => "other"', '  }', '}', 'const FROZEN: One = One.Chosen(7)'];
    writeFileSync(file, [...localHeader, 'export fn main() -> Int {',
      '  let a = One.Chosen(1)', '  let b = Two.Chosen(2)',
      '  let c = NamedOne.Held{value: 3}', '  let d = NamedTwo.Held{value: 4}',
      '  print(generic(&a))', '  print(generic(&b))', '  print(generic(&c))', '  print(generic(&d))',
      '  print(inspect(a))', '  print(inspect(b))', '  print(inspect(c))', '  print(inspect(d))',
      '  let create = One.Chosen', '  print(show(create(3)))', '  print(generic(&FROZEN))',
      '  match (FlagOne.On, FlagTwo.On) {', '    case (FlagOne.On, FlagTwo.On) => print("units")',
      '    case _ => panic("unit owners")', '  }', '  0', '}',
    ].join('\n') + '\n');
    const expected = 'one\ntwo\nnamed one\nnamed two\n'.repeat(2) + 'Chosen(3)\none\nunits\n';
    for (const mode of ['tree', 'compiled']) {
      run(expected, mode);
      run(expected, mode, cache);
      const stored = entries();
      run(expected, mode, cache);
      assert.deepEqual(entries(), stored, 'warm same-module variants retain owners');
    }
    for (const expression of ['Chosen(1)', 'Empty', 'Held{value: 1}']) {
      writeFileSync(file, [...localHeader, 'export fn main() -> Int {', `  let bad = ${expression}`, '  0', '}'].join('\n') + '\n');
      const rejected = call('check');
      assert.notEqual(rejected.status, 0);
      const output = rejected.stdout + rejected.stderr;
      assert.equal(output.match(/E2012/g)?.length, 1, output);
      assert.equal(output.match(/candidate declared here/g)?.length, 2, output);
      assert.doesNotMatch(output, /E2001/);
    }
    writeFileSync(file, [...localHeader, 'fn bad(value: One) -> Int {', '  match value {',
      '    case Chosen(_) => 1', '    case _ => 0', '  }', '}', 'export fn main() -> Int { 0 }',
    ].join('\n') + '\n');
    const ambiguousPattern = call('check');
    assert.notEqual(ambiguousPattern.status, 0);
    assert.equal((ambiguousPattern.stdout + ambiguousPattern.stderr).match(/E2012/g)?.length, 1);
    for (const [written, code] of [['One.Chosen()', 'E3003'], ['Two.Missing(1)', 'E3034']]) {
      writeFileSync(file, [...localHeader, 'export fn main() -> Int {', `  let bad = ${written}`, '  0', '}'].join('\n') + '\n');
      const rejected = call('check');
      assert.notEqual(rejected.status, 0);
      assert.match(rejected.stdout + rejected.stderr, new RegExp(code));
      assert.match(rejected.stdout + rejected.stderr, /Main\.pudu:\d+:\d+/);
    }
  }
  writeFileSync(file, ['module Main', 'type One = One | Chosen(Int)', 'type Two = One | Chosen(Int)',
    'const SAVED: One = One.Chosen(9)', 'export fn main() -> Int {',
    '  let construct = One.Chosen', '  let value = construct(7)', '  print(show(One.Chosen(8)))',
    '  match value {', '    case One.Chosen(n) => print(show(n))', '    case One.One => print("one")', '  }',
    '  match Two.One {', '    case Two.One => print("two")', '    case Two.Chosen(_) => print("chosen")', '  }',
    '  print(show(SAVED))', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) {
    const expected = 'Chosen(8)\n7\ntwo\nChosen(9)\n';
    run(expected, mode);
    run(expected, mode, cache);
    const stored = entries();
    run(expected, mode, cache);
    assert.deepEqual(entries(), stored, 'warm constructors keep the checked type qualifier');
  }
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Sums retain canonical owners, named storage order and patterns across calls, caches and tasks');
