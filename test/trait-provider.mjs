import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const scratch = mkdtempSync(join(tmpdir(), 'pudu-trait-provider-'));
const path = join(scratch, 'Case.pudu');
const call = (command, mode = 'compiled', caching = 'off') => spawnSync(binary, [command, path], {
  env: {...env, PUDU_EVAL: mode, PUDU_CACHE: caching}, encoding: 'utf8', timeout: 60000,
});
try {
  for (const owner of ['Int', 'Box']) for (const reversed of [false, true]) {
    const implementations = [
      `impl TextWire for ${owner} { fn encode(self: &Self) -> Str { "text" } }`,
      `impl IntWire for ${owner} { fn encode(self: &Self) -> Int { 7 } }`,
    ];
    if (reversed) implementations.reverse();
    const declarations = [
      'module Case', 'type Box = { value: Int }',
      'trait TextWire { fn encode(self: &Self) -> Str }',
      'trait IntWire { fn encode(self: &Self) -> Int }', ...implementations,
      'fn generic[T: TextWire](value: &T) -> Str { value.encode() }',
      'export fn main() -> Int {',
      `  let value: ${owner} = ${owner === 'Int' ? '1' : 'Box{value: 1}'}`,
    ];
    const valid = [...declarations,
      '  let text: Str = TextWire.encode(&value)',
      '  let whole: Int = IntWire.encode(&value)',
      '  print(text)', '  print(show(whole))', '  0', '}',
    ];
    writeFileSync(path, valid.join('\n') + '\n');
    const checked = call('check');
    assert.equal(checked.status, 0, checked.stdout + checked.stderr);
    const ran = call('run');
    assert.equal(ran.status, 0, ran.stdout + ran.stderr);
    assert.equal(ran.stdout, 'text\n7\n');
    for (const [expression, code] of [
      ['let wrong: Int = TextWire.encode(&value)', 'E3001'],
      ['let wrong: Str = IntWire.encode(&value)', 'E3001'],
      ['let wrong = value.encode()', 'E3013'],
      [`let wrong = ${owner}.encode(&value)`, 'E3013'],
    ]) {
      writeFileSync(path, [...declarations, '  ' + expression, '  0', '}'].join('\n') + '\n');
      const refused = call('check');
      assert.notEqual(refused.status, 0, `${owner} reversed=${reversed}: ${expression}\n${refused.stdout}${refused.stderr}`);
      assert.match(refused.stdout + refused.stderr, new RegExp(code));
      assert.match(refused.stdout + refused.stderr, new RegExp(`Case\\.pudu:${declarations.length + 1}:`));
    }
  }
  const cache = join(scratch, 'cache');
  const runExpected = expected => {
    for (const mode of ['tree', 'compiled']) for (const caching of ['off', cache, cache]) {
      const ran = call('run', mode, caching);
      assert.equal(ran.status, 0, `${mode}: ${ran.stdout}${ran.stderr}`);
      assert.equal(ran.stdout, expected);
    }
  };
  writeFileSync(join(scratch, 'Owner.pudu'), 'module Owner\nexport type Box = { value: Int }\n');
  for (const owner of ['Int', 'O.Box']) for (const reversed of [false, true]) {
    const names = reversed ? ['Second', 'First'] : ['First', 'Second'];
    for (const [name, result, body] of [[names[0], 'Str', '"first"'], [names[1], 'Int', '7']]) {
      writeFileSync(join(scratch, name + '.pudu'), [`module ${name}`, 'import Owner as O',
        `export trait Encode { fn encode(self: &Self) -> ${result} }`,
        `impl Encode for ${owner} { fn encode(self: &Self) -> ${result} { ${body} } }`,
      ].join('\n') + '\n');
    }
    const imports = [`import ${names[0]} as A`, `import ${names[1]} as B`];
    if (reversed) imports.reverse();
    const header = ['module Case', 'import Owner as O', ...imports];
    writeFileSync(path, [...header, 'export fn main() -> Int { print("loaded")', '  0', '}'].join('\n') + '\n');
    const unused = call('check');
    assert.equal(unused.status, 0, unused.stdout + unused.stderr);
    const declarations = [...header,
      'fn text[T: A.Encode](value: &T) -> Str { value.encode() }',
      'fn whole[T: B.Encode](value: &T) -> Int { value.encode() }',
      'fn explicit[T: A.Encode](value: &T) -> Str { A.Encode.encode(value) }',
      'fn retained[T: A.Encode](value: &T) -> Str { let selected = value.encode', '  selected()', '}',
      'export fn main() -> Int {', `  let value: ${owner} = ${owner === 'Int' ? '1' : 'O.Box{value: 1}'}`];
    writeFileSync(path, [...declarations,
      '  print(A.Encode.encode(&value))', '  print(show(B.Encode.encode(&value)))',
      '  print(text(&value))', '  print(show(whole(&value)))', '  print(retained(&value))',
      '  print(explicit(&value))', '  0', '}',
    ].join('\n') + '\n');
    runExpected('first\n7\nfirst\n7\nfirst\nfirst\n');
    for (const [expression, code] of [
      ['let wrong: Int = A.Encode.encode(&value)', 'E3001'],
      ['let wrong: Str = B.Encode.encode(&value)', 'E3001'],
      ['let wrong = value.encode()', 'E3013'],
      [`let wrong = ${owner}.encode(&value)`, 'E3013'],
    ]) {
      writeFileSync(path, [...declarations, '  ' + expression, '  0', '}'].join('\n') + '\n');
      const refused = call('check');
      const output = refused.stdout + refused.stderr;
      assert.notEqual(refused.status, 0, output);
      assert.equal(output.match(new RegExp(code, 'g'))?.length, 1, output);
      assert.match(output, new RegExp(`Case\\.pudu:${declarations.length + 1}:`));
      if (code === 'E3013') {
        assert(output.includes('A.Encode.encode('), output);
        assert(output.includes('B.Encode.encode('), output);
      }
    }
    const selected = ['module Case', 'import Owner as O', `import ${names[0]} { Encode }`,
      `import ${names[1]} as B`, 'fn text[T: Encode](value: &T) -> Str { value.encode() }',
      'export fn main() -> Int {', `  let value: ${owner} = ${owner === 'Int' ? '1' : 'O.Box{value: 1}'}`];
    writeFileSync(path, [...selected, '  print(Encode.encode(&value))', '  print(text(&value))',
      '  print(show(B.Encode.encode(&value)))', '  0', '}',
    ].join('\n') + '\n');
    runExpected('first\nfirst\n7\n');
    writeFileSync(path, ['module Case', 'import Owner as O', `import ${names[0]} as A`,
      `import ${names[0]} as Again`, 'export fn main() -> Int {',
      `  let value: ${owner} = ${owner === 'Int' ? '1' : 'O.Box{value: 1}'}`,
      '  print(value.encode())', '  print(Again.Encode.encode(&value))', '  0', '}',
    ].join('\n') + '\n');
    runExpected('first\nfirst\n');
    const mixed = ['module Case', 'import Owner as O', `import ${names[0]} as A`,
      'trait LOCALWIRE { fn encode(self: &Self) -> Int }',
      `impl LOCALWIRE for ${owner} { fn encode(self: &Self) -> Int { 9 } }`,
      'fn local[T: LOCALWIRE](value: &T) -> Int { value.encode() }',
      'export fn main() -> Int {', `  let value: ${owner} = ${owner === 'Int' ? '1' : 'O.Box{value: 1}'}`];
    writeFileSync(path, [...mixed, '  print(A.Encode.encode(&value))',
      '  print(show(LOCALWIRE.encode(&value)))', '  print(show(local(&value)))', '  0', '}',
    ].join('\n') + '\n');
    runExpected('first\n9\n9\n');
    writeFileSync(path, [...mixed, `  const LOCALWIRE: ${owner} = ${owner === 'Int' ? '1' : 'O.Box{value: 1}'}`,
      '  let wrong = LOCALWIRE.encode(&value)', '  0', '}',
    ].join('\n') + '\n');
    const shadowed = call('check');
    assert.notEqual(shadowed.status, 0);
    assert.equal((shadowed.stdout + shadowed.stderr).match(/E3013/g)?.length, 1, shadowed.stdout + shadowed.stderr);

  }
  writeFileSync(path, ['module Case', 'trait Single { fn encode(self: &Self) -> Int }',
    'impl Single for Int { fn encode(self: &Self) -> Int { 1 } }',
    'impl Single for Int { fn encode(self: &Self) -> Int { 2 } }',
    'export fn main() -> Int { 0 }',
  ].join('\n') + '\n');
  const duplicate = call('check');
  assert.notEqual(duplicate.status, 0);
  assert.equal((duplicate.stdout + duplicate.stderr).match(/E3015/g)?.length, 1, duplicate.stdout + duplicate.stderr);
  writeFileSync(join(scratch, 'Wire.pudu'), [
    'module Wire', 'import Std.Meta', 'export trait Encode { fn encode(self: &Self) -> Int }',
    'impl Encode for Int { fn encode(self: &Self) -> Int { *self } }',
    'impl Encode for Str { fn encode(self: &Self) -> Int { self.length() } }',
    'export derive Encode for T: Record {', '  fn encode(self: &T) -> Int {', '    var total = 0',
    '    for part in Meta.collect[T](fn(member: Meta.Field[T, F]) -> Option[Int] where F: Encode {',
    '      Some(member.get(self).encode())', '    }) { total = total + part }', '    total', '  }', '}',
  ].join('\n') + '\n');
  writeFileSync(path, ['module Case', 'import Std.Json as Json', 'import Wire',
    'type Point = { x: Int, name: Str } derives Json.Encode, Wire.Encode',
    'fn wired[T: Wire.Encode](value: &T) -> Int { value.encode() }',
    'fn json[T: Json.Encode](value: &T) -> Str { Json.encode(&value.encode()) }',
    'export fn main() -> Int {', '  print(show(wired(&Point{x: 40, name: "ab"})))',
    '  print(json(&Point{x: 1, name: "c"}))',
    '  print(show(Wire.Encode.encode(&Point{x: 1, name: ""})))', '  0', '}',
  ].join('\n') + '\n');
  runExpected('42\n{"x":1,"name":"c"}\n1\n');
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Trait provider results, execution, bound typing and positioned refusals passed');
