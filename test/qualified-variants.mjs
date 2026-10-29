import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const scratch = mkdtempSync(join(tmpdir(), 'pudu-qualified-variants-'));
const run = (...args) => execFileSync(binary, args, {cwd: scratch, encoding: 'utf8', timeout: 60000});
const check = (source, code, line) => {
  const path = join(scratch, 'Main.pudu');
  writeFileSync(path, source);
  const result = spawnSync(binary, ['check', path], {cwd: scratch, encoding: 'utf8', timeout: 60000});
  assert.notEqual(result.status, 0, source);
  assert.match(result.stdout + result.stderr, new RegExp('error\\[' + code + '\\]'), source);
  assert.match(result.stdout + result.stderr, new RegExp('Main\\.pudu:' + line + ':'), source);
};
try {
  writeFileSync(join(scratch, 'Shapes.pudu'), 'module Shapes\nexport type Failure = Invalid | Detail(Int)\nexport type Boxed[T] = Empty | Full(T)\nexport type Named = Circle{radius: Int} | Dot\ntype Secret = Hidden | OtherHidden\n');
  const main = join(scratch, 'Main.pudu');
  writeFileSync(main, `module Main
import Shapes as S
export fn main() -> Int {
  let failure: S.Failure = S.Failure.Invalid
  let make = S.Failure.Detail
  let detail: S.Failure = make(3)
  let boxed: S.Boxed[Int] = S.Boxed.Full(7)
  let named = S.Named.Circle{radius: 4}
  let size = match detail {
    case S.Failure.Detail(value) => value
    case S.Failure.Invalid => 0
  }
  let value = match boxed {
    case S.Boxed.Full(item) => item
    case S.Boxed.Empty => 0
  }
  if failure != S.Failure.Invalid || size != 3 || value != 7 { panic("qualified values") }
  match named {
    case S.Named.Circle{radius} => if radius != 4 { panic("named payload") }
    case S.Named.Dot => panic("named tag")
  }
  print("qualified variants: ok")
  0
}
`);
  assert.equal(run('run', main), 'qualified variants: ok\n');
  run('fmt', '--check', main, join(scratch, 'Shapes.pudu'));
  writeFileSync(main, 'module Main\nimport Shapes\nexport fn main() -> Int {\n  let found: Shapes.Failure = Shapes.Failure.Detail(2)\n  if found != Shapes.Failure.Detail(2) { panic("unaliased") }\n  0\n}\n');
  assert.equal(run('run', main), '');
  writeFileSync(main, 'module Main\ntype Local = Unit | Value(Int)\nexport fn main() -> Int {\n  let make = Local.Value\n  let value: Local = make(4)\n  if value != Local.Value(4) || Local.Unit == value { panic("local") }\n  0\n}\n');
  assert.equal(run('run', main), '');
  writeFileSync(main, 'module Main\ntype Local = Unit | Value(Int)\ntrait Factory { fn parse() -> Self }\nimpl Factory for Local { fn parse() -> Local { Unit } }\nexport fn main() -> Int {\n  if Local.parse() != Local.Unit { panic("sum method") }\n  0\n}\n');
  assert.equal(run('run', main), '');
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let wrong: Int = S.Failure.Invalid\n  0\n}\n', 'E3001', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let wrong: Str = S.Failure.Detail(3)\n  0\n}\n', 'E3001', 4);
  check('module Main\ntype Local = Unit | Value(Int)\nexport fn main() -> Int {\n  let wrong: Int = Local.Value(3)\n  0\n}\n', 'E3001', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let wrong: S.Boxed[Int] = S.Boxed.Full("text")\n  0\n}\n', 'E3001', 4);
  check('module Main\ntype Local = Unit | Value(Int)\nexport fn main() -> Int {\n  let wrong: Str = Local.Unit\n  0\n}\n', 'E3001', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let make: fn(Int) -> Int = S.Failure.Detail\n  0\n}\n', 'E3001', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let missing = S.Failure.Missing\n  0\n}\n', 'E3034', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let hidden = S.Secret.Hidden\n  0\n}\n', 'E3033', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let called = S.Named.Circle(3)\n  0\n}\n', 'E3034', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  let captured = S.Named.Circle\n  0\n}\n', 'E3034', 4);
  check('module Main\nimport Shapes as S\nexport fn main() -> Int {\n  const S = 3\n  let invalid = S.Failure.Detail(2)\n  0\n}\n', 'E3005', 5);
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Qualified constructors preserve nominal types, values, visibility and lexical heads');
