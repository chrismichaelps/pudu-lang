import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scratch = mkdtempSync(join(tmpdir(), 'pudu-qualified-record-'));
const path = join(scratch, 'Main.pudu');
const cache = join(scratch, 'cache');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const call = (command, mode = 'compiled', caching = 'off') => spawnSync(binary, [command, path], {
  env: {...env, PUDU_EVAL: mode, PUDU_CACHE: caching}, encoding: 'utf8', timeout: 60000,
});
const entries = () => readdirSync(cache, {recursive: true}).map(name => join(cache, name))
  .filter(name => statSync(name).isFile()).sort().map(name => [name, statSync(name).ino]);
try {
  writeFileSync(join(scratch, 'Contract.pudu'), [
    'module Contract', 'export trait Label { fn label(self: &Self) -> Str }',
    'export trait Build { fn make(value: Int) -> Self }',
  ].join('\n') + '\n');
  for (const [name, label] of [['First', 'first'], ['Second', 'second']]) {
    writeFileSync(join(scratch, `${name}.pudu`), [
      `module ${name}`, 'import Contract { Label, Build }', `const NAME: Str = "${label}"`,
      'export type Item = { value: Int }', 'export type Box[T] = { held: T }',
      'type Hidden = { value: Int }', 'export const INSTANCE: Item = Item{value: 1}',
      'impl Label for Item { fn label(self: &Self) -> Str { NAME } }',
      'impl[T] Label for Box[T] { fn label(self: &Self) -> Str { NAME } }',
      'impl Build for Item { fn make(value: Int) -> Self { Item{value} } }',
      'export fn make() -> Item { Item{value: 1} }',
    ].join('\n') + '\n');
  }
  for (const selected of [false, true]) for (const reversed of [false, true]) {
    const imports = [selected ? 'import First { Item, Box, make }' : 'import First as A', 'import Second as B'];
    if (reversed) imports.reverse();
    const item = selected ? 'Item' : 'A.Item';
    const box = selected ? 'Box' : 'A.Box';
    const header = ['module Main', 'import Contract { Label, Build }', ...imports];
    const main = ['export fn main() -> Int {', `  let a = ${selected ? 'make' : 'A.make'}()`, '  let b = B.make()'];
    writeFileSync(path, [...header, ...main,
      `  print(${item}.label(&a))`, `  let retained = ${item}.label`, '  print(retained(&a))',
      '  print(B.Item.label(&b))', '  let saved = B.Item.label', '  print(saved(&b))',
      `  let built = ${item}.make(9)`, '  print(show(built.value))',
      `  let boxed = ${box}{held: 7}`, `  print(${box}.label(&boxed))`,
      `  let generic = ${box}.label`, '  print(generic(&boxed))',
      '  print(show(a))',
      '  print(B.INSTANCE.label())', '  let valueMethod = B.INSTANCE.label',
      '  print(valueMethod())', '  0', '}',
    ].join('\n') + '\n');
    for (const mode of ['tree', 'compiled']) {
      let warmed = false;
      for (const caching of ['off', cache, cache]) {
        const before = caching === cache && warmed ? entries() : [];
        const result = call('run', mode, caching);
        assert.equal(result.status, 0, result.stdout + result.stderr);
        assert.equal(result.stdout, 'first\nfirst\nsecond\nsecond\n9\nfirst\nfirst\nItem{value: 1}\nsecond\nsecond\n');
        if (before.length) assert.deepEqual(entries(), before, 'warm products must be reused');
        if (caching === cache) { assert(entries().length >= 8); warmed = true; }
      }
    }
    for (const [statement, code] of [
      [`let wrong: Int = ${item}.label(&a)`, 'E3001'],
      [`let wrong = ${item}.label(&b)`, 'E3001'],
      [`let wrong = ${item}.absent(&a)`, 'E3034'],
      ['let wrong = B.Hidden.label(&b)', 'E3033'],
      ['const B: Int = 1\n  let wrong = B.Item.label(&a)', 'E3005'],
    ]) {
      writeFileSync(path, [...header, ...main, `  ${statement}`, '  0', '}'].join('\n') + '\n');
      const result = call('check');
      assert.notEqual(result.status, 0, statement);
      assert.match(result.stdout + result.stderr, new RegExp(code));
      assert.match(result.stdout + result.stderr, /Main\.pudu:\d+:\d+/);
      if (statement.startsWith('const B')) assert.doesNotMatch(result.stdout + result.stderr, /E3033/);
    }
  }
  writeFileSync(path, [
    'module Main', 'trait Left { fn encode(self: &Self) -> Str }',
    'trait Right { fn encode(self: &Self) -> Int }',
    'impl Left for Int { fn encode(self: &Self) -> Str { "left" } }',
    'impl Right for Int { fn encode(self: &Self) -> Int { 1 } }',
    'export fn main() -> Int {', '  let value: Int = 1', '  let wrong = Int.encode(&value)', '  0', '}',
  ].join('\n') + '\n');
  const ambiguous = call('check');
  assert.notEqual(ambiguous.status, 0);
  const diagnostics = ambiguous.stdout + ambiguous.stderr;
  assert.equal((diagnostics.match(/error\[E3013\]/g) || []).length, 1, diagnostics);
  assert.match(diagnostics, /Main\.pudu:\d+:\d+/);
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Qualified record methods preserve canonical schemes, captures and cache reuse');
