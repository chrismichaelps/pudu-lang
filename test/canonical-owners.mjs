import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scratch = mkdtempSync(join(tmpdir(), 'pudu-canonical-owner-'));
const file = join(scratch, 'Main.pudu');
const cache = join(scratch, 'cache');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const call = (command, mode = 'compiled', caching = 'off') => spawnSync(binary, [command, file], {
  env: {...env, PUDU_EVAL: mode, PUDU_CACHE: caching}, encoding: 'utf8', timeout: 60000,
});
const entries = () => readdirSync(cache, {recursive: true}).map(name => join(cache, name))
  .filter(name => statSync(name).isFile()).sort().map(name => [name, statSync(name).ino]);
try {
  writeFileSync(join(scratch, 'Contract.pudu'),
    'module Contract\nexport trait Label { fn label(self: &Self) -> Str }\n');
  for (const [module, label] of [['First', 'first'], ['Second', 'second']]) {
    writeFileSync(join(scratch, `${module}.pudu`), [
      `module ${module}`, 'import Contract { Label }',
      'export type Item = { value: Int }', `const NAME: Str = "${label}"`,
      'const INSTANCE: Item = Item{value: 1}',
      'impl Label for Item { fn label(self: &Self) -> Str { NAME } }',
      'export fn make() -> Item { Item{value: 1} }',
      'export fn frozen() -> Item { INSTANCE }',
      'export fn explicit(value: &Item) -> Str { Item.label(value) }',
    ].join('\n') + '\n');
  }
  for (const reversed of [false, true]) {
    const imports = ['import First as A', 'import Second as B'];
    if (reversed) imports.reverse();
    const declarations = [
      'module Main', 'import Contract { Label }', ...imports,
      'fn generic[T: Label](value: &T) -> Str { value.label() }',
      'fn alias[T: Label](value: &T) -> Str {', '  let held = value', '  held.label()', '}',
    ];
    const main = ['export fn main() -> Int {', '  let first = A.make()', '  let second = B.make()'];
    const program = [...declarations, ...main,
      '  print(first.label())', '  print(second.label())',
      '  print(generic(&first))', '  print(generic(&second))',
      '  let f = first.label', '  let s = second.label', '  print(f())', '  print(s())',
      '  print(alias(&first))', '  print(alias(&second))',
      '  print(A.explicit(&first))', '  print(B.explicit(&second))',
      '  let frozenA = A.frozen()', '  let frozenB = B.frozen()',
      '  print(generic(&frozenA))', '  print(generic(&frozenB))',
      '  print(show(first))',
      '  match first { case A.Item{value} => print(show(value)) }', '  0', '}',
    ].join('\n') + '\n';
    writeFileSync(file, program);
    for (const mode of ['tree', 'compiled']) {
      let warmed = false;
      for (const caching of ['off', cache, cache]) {
        const before = caching === cache && warmed ? entries() : [];
        const result = call('run', mode, caching);
        assert.equal(result.status, 0, result.stdout + result.stderr);
        assert.equal(result.stdout, 'first\nsecond\n'.repeat(6) + 'Item{value: 1}\n1\n');
        if (before.length) assert.deepEqual(entries(), before, 'warm products must be reused');
        if (caching === cache) {
          assert(entries().length >= 8, 'four modules must store frontend and checked products');
          warmed = true;
        }
      }
    }
    writeFileSync(file, [...declarations, ...main,
      '  let wrong: A.Item = second', '  0', '}',
    ].join('\n') + '\n');
    const wrong = call('check');
    assert.notEqual(wrong.status, 0);
    assert.match(wrong.stdout + wrong.stderr, /E3001/);
    assert.match(wrong.stdout + wrong.stderr, /Main\.pudu:\d+:\d+/);
  }
  writeFileSync(file, [
    'module Main', 'import Std.FlatMap as FlatMap', 'import Std.MultiMap as MultiMap',
    'import Std.Xml as Xml', 'export fn main() -> Int {',
    '  let flat: FlatMap.FlatMap[Int] = FlatMap.empty(16)',
    '  let flatCopy: FlatMap.FlatMap[Int] = FlatMap.FlatMap{',
    '    capacity: flat.capacity, count: flat.count, ctrl: flat.ctrl, slots: flat.slots', '  }',
    '  if flat != flatCopy { panic("flat owner") }',
    '  let initial: MultiMap.MultiMap[Int, Int] = MultiMap.empty()',
    '  let many = MultiMap.add(&initial, 1, 2)',
    '  let manyCopy = MultiMap.MultiMap{groups: many.groups, occurrences: many.occurrences}',
    '  if many != manyCopy { panic("multimap owner") }',
    '  let Some(tag) = xmlDecode("<root/>") else { panic("xml decode") }',
    '  let tagCopy = Xml.Tag{name: tag.name, attributes: tag.attributes, children: tag.children}',
    '  if tag != tagCopy { panic("xml owner") }', '  print("native owners agree")', '  0', '}',
  ].join('\n') + '\n');
  for (const mode of ['tree', 'compiled']) {
    const result = call('run', mode);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stdout, 'native owners agree\n');
  }
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Canonical record owners retain direct, generic, captured and cached dispatch');
