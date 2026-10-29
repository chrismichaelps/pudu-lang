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
const call = command => spawnSync(binary, [command, path], {env, encoding: 'utf8', timeout: 60000});
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
} finally { rmSync(scratch, {recursive: true, force: true}); }
console.log('Trait provider results, execution, bound typing and positioned refusals passed');
