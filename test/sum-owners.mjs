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
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Positional sums retain owners across calls, caches, tasks and native nodes');
