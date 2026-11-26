{-| @Test.Backend.LedgerAuditPrograms — one dense program per coverage-ledger
    claim, compared against the interpreter in both engines. -}
module Pudu.Backend.LedgerAuditPrograms (ledgerAuditPrograms, ledgerAuditRefusals) where

import Data.Text (Text)
import qualified Data.Text as Text

ledgerAuditPrograms :: [(String, [(FilePath, Text)], Text, Text)]
ledgerAuditPrograms =
  [ ( "pattern forms, guards, sequence patterns, let-else and every iterated shape"
    , []
    , Text.unlines
        [ "module Main"
        , "type Shape = Circle(Float) | Rect(Int, Int) | Named { label: Str, sides: Int } | Empty"
        , "type Point = { x: Int, y: Int }"
        , "fn describe(s: Shape) -> Str {"
        , "  match s {"
        , "    case Circle(r) if r > 10.0 => \"big circle\""
        , "    case Circle(_) => \"circle\""
        , "    case Rect(w, h) if w == h => \"square \" + display(w)"
        , "    case Rect(1, _) | Rect(_, 1) => \"thin\""
        , "    case Rect(w, h) => \"rect \" + display(w * h)"
        , "    case Named { label: \"tri\", sides } => \"triangle \" + display(sides)"
        , "    case Named { label, sides: 4 } => \"quad \" + label"
        , "    case Named { label, sides } => label + display(sides)"
        , "    case Empty => \"empty\""
        , "  }"
        , "}"
        , "fn classify(n: Int) -> Str {"
        , "  match n { case 0 => \"zero\" case 1..=9 => \"digit\" case 10..100 => \"small\" case _ if n < 0 => \"neg\" case _ => \"big\" }"
        , "}"
        , "fn main() -> Int {"
        , "  for s in [Circle(20.0), Circle(1.0), Rect(3, 3), Rect(1, 5), Rect(2, 4), Named{label: \"tri\", sides: 3}, Named{label: \"box\", sides: 4}, Named{label: \"hex\", sides: 6}, Empty] { print(describe(s)) }"
        , "  for n in [0, 5, 9, 10, 99, 100, -3] { print(classify(n)) }"
        , "  let p = Point{x: 1, y: 2}"
        , "  let x = p.x"
        , "  let y = p.y"
        , "  print(display(x + y))"
        , "  let (a, (b, c)) = (1, (2, 3))"
        , "  print(display(a + b + c))"
        , "  if let Some(v) = Some(5) { print(display(v)) } else { print(\"none\") }"
        , "  let items = [1, 2, 3, 4, 5]"
        , "  match items { case [first, ..rest] => print(display(first) + show(rest)) case _ => print(\"empty\") }"
        , "  match items { case [.., last] => print(display(last)) case _ => print(\"?\") }"
        , "  match items { case [a1, b1, ..middle, z] => print(display(a1 + b1 + z) + show(middle)) case _ => print(\"short\") }"
        , "  var queue = [3, 2, 1]"
        , "  while let [head, ..tail] = queue {"
        , "    queue = tail"
        , "    if head == 2 { continue }"
        , "    print(\"head \" + display(head))"
        , "  }"
        , "  let Some(kept) = Some(9) else { return 1 }"
        , "  print(display(kept))"
        , "  for (k, v) in mapOf([(\"b\", 2), (\"a\", 1)]) { print(k + display(v)) }"
        , "  for m in setOf([3, 1, 2]) { print(display(m)) }"
        , "  for ch in \"hé\" { print(ch.toText()) }"
        , "  for i in 0..3 { print(display(i)) }"
        , "  for i in (1..=7).step(3) { print(display(i)) }"
        , "  var total = 0"
        , "  for row in [[1, 2], [3]] { for cell in row { total = total + cell } }"
        , "  print(display(total))"
        , "  0"
        , "}"
        ]
    , "big circle\ncircle\nsquare 3\nthin\nrect 8\ntriangle 3\nquad box\nhex6\nempty\nzero\ndigit\ndigit\nsmall\nsmall\nbig\nneg\n3\n6\n5\n1[2, 3, 4, 5]\n5\n8[3, 4]\nhead 3\nhead 1\n9\na1\nb2\n1\n2\n3\nh\né\n0\n1\n2\n1\n4\n7\n6\n" )
  , ( "trait defaults, generic bounds, composed lambdas, bound methods and callable arrays"
    , []
    , Text.unlines
        [ "module Main"
        , "trait Greeter { fn greet(self: &Self) -> Str"
        , "  fn twice(self: &Self) -> Str { self.greet() + self.greet() } }"
        , "type En = { name: Str }"
        , "type Es = { name: Str }"
        , "impl Greeter for En { fn greet(self: &Self) -> Str { \"hi \" + self.name } }"
        , "impl Greeter for Es { fn greet(self: &Self) -> Str { \"hola \" + self.name }"
        , "  fn twice(self: &Self) -> Str { \"¡\" + self.greet() + \"!\" } }"
        , "fn both[T: Greeter](items: &Array[T]) -> Str { var out = \"\""
        , "  for it in items { out = out + it.twice() + \";\" }"
        , "  out }"
        , "fn compose[A, B, C](f: fn(A) -> B, g: fn(B) -> C) -> fn(A) -> C { |x| g(f(x)) }"
        , "fn counter() -> Int { 0 }"
        , "fn pick(flag: Bool) -> fn(Int) -> Int { if flag { |x| x * 10 } else { |x| x - 1 } }"
        , "fn main() -> Int {"
        , "  print(both(&[En{name: \"a\"}, En{name: \"b\"}]) + both(&[Es{name: \"c\"}]))"
        , "  let inc = compose(fn(x: Int) -> Int { x + 1 }, fn(x: Int) -> Str { display(x) + \"!\" })"
        , "  print(inc(41))"
        , "  print(display(pick(true)(4)) + \" \" + display(pick(false)(4)))"
        , "  let greet = En{name: \"v\"}.greet"
        , "  print(greet())"
        , "  let fs = [fn(x: Int) -> Int { x + 1 }, fn(x: Int) -> Int { x * x }]"
        , "  var acc = 3"
        , "  for f in fs { acc = f(acc) }"
        , "  print(display(acc))"
        , "  let words = [\"pear\", \"fig\", \"apple\"]"
        , "  print(show(words.map(fn(w: Str) -> Int { w.length() })) + show(words.filter(fn(w: Str) -> Bool { w.length() > 3 })) + show(words.sortBy(fn(a: Str, b: Str) -> Bool { a.length() < b.length() })))"
        , "  0"
        , "}"
        ]
    , "hi ahi a;hi bhi b;¡hola c!;\n42!\n40 3\nhi v\n16\n[4, 3, 5][\"pear\", \"apple\"][\"fig\", \"pear\", \"apple\"]\n" )
  , ( "generic records, recursive sums, sorted tuples, map, set and range queries"
    , []
    , Text.unlines
        [ "module Main"
        , "type Pair[A, B] = { first: A, second: B }"
        , "type Tree = Leaf | Node(Tree, Int, Tree)"
        , "fn insert(t: Tree, v: Int) -> Tree { match t { case Leaf => Node(Leaf, v, Leaf)"
        , "  case Node(l, x, r) => if v < x { Node(insert(l, v), x, r) } else { Node(l, x, insert(r, v)) } } }"
        , "fn walk(t: &Tree) -> Array[Int] { match t { case Leaf => [] case Node(l, x, r) => walk(&l).push(x).concat(walk(&r)) } }"
        , "fn main() -> Int {"
        , "  let p = Pair{first: 1, second: \"x\"}"
        , "  let q = Pair{first: [1, 2], second: Pair{first: true, second: 2.5}}"
        , "  print(show(p) + \" \" + show(q) + \" \" + display(p == Pair{first: 1, second: \"x\"}))"
        , "  var t = Leaf"
        , "  for v in [5, 2, 8, 1, 9, 3] { t = insert(t, v) }"
        , "  print(show(walk(&t)))"
        , "  let tuples = [(2, \"b\"), (1, \"z\"), (2, \"a\")]"
        , "  print(show(tuples.sortBy(fn(a: (Int, Str), b: (Int, Str)) -> Bool { a < b })))"
        , "  var m: Map[Str, Array[Int]] = mapOf([])"
        , "  for (k, v) in [(\"a\", 1), (\"b\", 2), (\"a\", 3)] { m = m.insert(k, (match m.get(k) { case Some(old) => old case None => [] }).push(v)) }"
        , "  print(show(m) + display(m.size()) + show(m.keys()) + show(m.values()) + show(m.get(\"zz\")))"
        , "  let s = setOf([3, 1, 2]).union(setOf([4])).difference(setOf([1]))"
        , "  print(show(s) + display(s.contains(2)) + show(s.intersect(setOf([2, 9]))))"
        , "  let r = 1..10"
        , "  print(show(r) + display(r.contains(5)) + display(r.length()))"
        , "  let arr = [5, 3, 8]"
        , "  print(show(arr.sortBy(fn(a: Int, b: Int) -> Bool { a < b })) + display(arr.contains(8)) + display(arr.length()))"
        , "  print(show(Some((1, [2]))) + show(Ok[Int, Str](3)) + show(Err[Int, Str](\"e\")))"
        , "  0"
        , "}"
        ]
    , "Pair{first: 1, second: \"x\"} Pair{first: [1, 2], second: Pair{first: true, second: 2.5}} true\n[1, 2, 3, 5, 8, 9]\n[(1, \"z\"), (2, \"a\"), (2, \"b\")]\n{\"a\": [1, 3], \"b\": [2]}2[\"a\", \"b\"][[1, 3], [2]]None\n#{2, 3, 4}true#{2}\n1..10true9\n[3, 5, 8]true3\nSome((1, [2]))Ok(3)Err(\"e\")\n" )
  , ( "qualified, selective and value calls into a module's functions and constants, callable constants included"
    , [("Shapes.pudu", Text.unlines
        [ "module Shapes"
        , "export type Kind = Square | Circle"
        , "export type Spec = { kind: Kind, size: Int }"
        , "export type Size = Int"
        , "export const UNIT: Spec = Spec{kind: Square, size: 1}"
        , "export const SIZES: Array[Size] = [1, 2, 3]"
        , "export const NAMES: Map[Str, Int] = mapOf([(\"one\", 1), (\"two\", 2)])"
        , "export const MARKS: Set[Str] = setOf([\"a\", \"b\"])"
        , "export const SPAN: Range[Int] = 0..4"
        , "export const PAIR: (Int, Str) = (7, \"seven\")"
        , "export const BLOB: Bytes = bytesOf([1, 2, 255])"
        , "export const DOUBLE: fn(Int) -> Int = fn(x: Int) -> Int { x * 2 }"
        , "export fn area(s: &Spec) -> Int { match s.kind { case Square => s.size * s.size case Circle => 3 * s.size * s.size } }"
        , "export fn scaled(s: Spec, by: Size = 2) -> Spec { Spec{kind: s.kind, size: s.size * by} }" ])]
    , Text.unlines
        [ "module Main"
        , "import Shapes as Geo"
        , "import Shapes {area, Spec, Circle}"
        , "const LOCAL: Int = 40 + 2"
        , "const WORDS: Array[Str] = [\"x\", \"y\"]"
        , "fn main() -> Int {"
        , "  let c = Spec{kind: Circle, size: 2}"
        , "  print(display(area(&c)) + \" \" + display(Geo.area(&Geo.UNIT)) + \" \" + show(Geo.UNIT) + \" \" + show(Geo.scaled(c)) + \" \" + show(Geo.scaled(c, 5)))"
        , "  print(show(Geo.SIZES) + show(Geo.NAMES) + show(Geo.MARKS) + show(Geo.SPAN) + show(Geo.PAIR) + show(Geo.BLOB))"
        , "  print(display(Geo.DOUBLE(21)) + \" \" + display(LOCAL) + show(WORDS))"
        , "  let f = Geo.area"
        , "  let g = Geo.scaled"
        , "  print(display(f(&Geo.UNIT)) + show(g(Geo.UNIT, 3)))"
        , "  let s: Geo.Size = 9"
        , "  print(display(s) + display(c == Spec{kind: Circle, size: 2}))"
        , "  for v in Geo.SIZES { print(display(Geo.DOUBLE(v))) }"
        , "  0"
        , "}"
        ]
    , "12 1 Spec{kind: Square, size: 1} Spec{kind: Circle, size: 4} Spec{kind: Circle, size: 10}\n[1, 2, 3]{\"one\": 1, \"two\": 2}#{\"a\", \"b\"}0..4(7, \"seven\")0x0102ff\n42 42[\"x\", \"y\"]\n1Spec{kind: Square, size: 3}\n9true\n2\n4\n6\n" )
  , ( "cells, counters across started tasks, and a closed channel drained"
    , []
    , Text.unlines
        [ "module Main"
        , "import Std.Sync as Sync"
        , "import Std.Channel as Channel"
        , "import Std.Concurrent as Concurrent"
        , "fn main() -> Int {"
        , "  let cell = Sync.cell(0)"
        , "  let total = Sync.counter(0)"
        , "  print(show(Sync.set(&cell, 5)) + show(Sync.get(&cell)) + show(Sync.swap(&cell, 8)) + show(Sync.get(&cell)))"
        , "  var tasks: Array[Concurrent.Task] = []"
        , "  for i in 1..=4 {"
        , "    let started = Concurrent.start(fn() -> () { let _ = Sync.increment(&total, i) })"
        , "    match started { case Ok(t) => { tasks = tasks.push(t) } case Err(_) => () }"
        , "  }"
        , "  print(show(Concurrent.joinAll(&tasks)) + show(Sync.count(&total)))"
        , "  let ch: Channel.Channel[Int] = Channel.channel(4)"
        , "  print(show(Channel.send(&ch, 1)) + show(Channel.send(&ch, 2)) + show(Channel.pending(&ch)) + show(Channel.close(&ch)) + show(Channel.drain(&ch)))"
        , "  0"
        , "}"
        ]
    , "Ok(())Ok(5)Ok(5)Ok(8)\nOk(())Ok(10)\nOk(())Ok(())Ok(2)Ok(())Ok([1, 2])\n" )
  , ( "text conversions to Int, Float and Decimal across signs, bases and overflow"
    , []
    , Text.unlines
        [ "module Main"
        , "fn main() -> Int {"
        , "  let samples = [\"42\", \"-17\", \"+5\", \"0x1F\", \"  9  \", \"\", \"abc\", \"3.25\", \"-0.0\", \"1e3\", \"nan\", \"9223372036854775807\", \"9223372036854775808\", \"-9223372036854775808\", \"1_000\", \"١٢\"]"
        , "  for s in samples {"
        , "    print(s + \" | \" + show(s.toInt()) + \" | \" + show(s.toFloat()) + \" | \" + show(s.toDecimal()))"
        , "  }"
        , "  for code in [65, 0, 127, 128, 233, 55296, 57343, 65535, 1114111, 1114112, -1] { print(display(code) + \" \" + show(charFromCode(code))) }"
        , "  let chars = \"héllo😀\".chars()"
        , "  print(show(chars) + display(chars.length()))"
        , "  for c in chars { print(display(c.code()) + \" \" + c.toText() + \" \" + show(c)) }"
        , "  let bytes = \"héllo😀\".toBytes()"
        , "  print(show(bytes) + \" \" + display(bytes.length()))"
        , "  print(show(bytesOf([104u8, 195u8, 169u8])) + \" \" + show(bytesOf([255u8, 0u8])))"
        , "  print(display(12.5) + \" \" + display(0.1 + 0.2) + \" \" + display(1.0 / 3.0) + \" \" + show(-0.0) + \" \" + display(1e21) + \" \" + display(123456789.0))"
        , "  0"
        , "}"
        ]
    , "42 | Some(42) | Some(42.0) | Some(42)\n-17 | Some(-17) | Some(-17.0) | Some(-17)\n+5 | Some(5) | Some(5.0) | Some(5)\n0x1F | None | None | None\n  9   | None | None | None\n | None | None | None\nabc | None | None | None\n3.25 | None | Some(3.25) | Some(3.25)\n-0.0 | None | Some(-0.0) | Some(0.0)\n1e3 | None | Some(1000.0) | Some(1000)\nnan | None | None | None\n9223372036854775807 | Some(9223372036854775807) | Some(9.223372036854776e18) | Some(9223372036854775807)\n9223372036854775808 | None | Some(9.223372036854776e18) | Some(9223372036854775808)\n-9223372036854775808 | Some(-9223372036854775808) | Some(-9.223372036854776e18) | Some(-9223372036854775808)\n1_000 | None | None | None\n١٢ | None | None | None\n65 Some('A')\n0 Some('\0\&')\n127 Some('\127\&')\n128 Some('\128\&')\n233 Some('é')\n55296 None\n57343 None\n65535 Some('\65535\&')\n1114111 Some('\1114111\&')\n1114112 None\n-1 None\n['h', 'é', 'l', 'l', 'o', '😀']6\n104 h 'h'\n233 é 'é'\n108 l 'l'\n108 l 'l'\n111 o 'o'\n128512 😀 '😀'\n0x68c3a96c6c6ff09f9880 10\n0x68c3a9 0xff00\n12.5 0.30000000000000004 0.3333333333333333 -0.0 1.0e21 1.23456789e8\n" )
  , ( "text methods taken as values and called later"
    , []
    , Text.unlines
        [ "module Main"
        , "fn apply(f: fn(Str) -> Str, s: Str) -> Str { f(s) }"
        , "fn main() -> Int {"
        , "  let upper = \"x\".toUpper"
        , "  let trimmed = \"  pad  \".trim"
        , "  let rep = \"ab\".repeat"
        , "  let sp = \"a,b,,c\".split"
        , "  let has = \"hello\".contains"
        , "  let starts = \"hello\".startsWith"
        , "  let idx = \"hello\".indexOf"
        , "  let slicer = \"hello\".slice"
        , "  print(upper() + \"|\" + trimmed() + \"|\" + rep(3) + \"|\" + show(sp(\",\")) + \"|\" + display(has(\"ell\")) + display(starts(\"he\")) + \"|\" + display(idx(\"l\")) + \"|\" + slicer(1, 3))"
        , "  print(apply(fn(s: Str) -> Str { s.toLower() }, \"MiXeD\"))"
        , "  let display1 = display"
        , "  let show1 = show"
        , "  print(display1(3) + show1(\"q\\\"uote\"))"
        , "  let fromCode = charFromCode"
        , "  let pack = bytesOf"
        , "  print(show(fromCode(97)) + show(pack([1u8, 2u8])))"
        , "  let parts = [\"b\", \"a\", \"c\"]"
        , "  print(parts.join(\"-\") + \" \" + show(parts.map(fn(s: Str) -> Str { s + s })))"
        , "  let lines = \"one\\ntwo\\r\\nthree\".lines()"
        , "  print(show(lines) + display(lines.length()))"
        , "  let e = \"<&>\".escapeHtml"
        , "  print(e())"
        , "  let b = \"abc\".toBytes()"
        , "  let sliceB = b.slice"
        , "  print(show(sliceB(1, 3)) + show(b.toText()))"
        , "  0"
        , "}"
        ]
    , "X|pad|ababab|[\"a\", \"b\", \"\", \"c\"]|truetrue|2|el\nmixed\n3\"q\\\"uote\"\nSome('a')0x0102\nb-a-c [\"bb\", \"aa\", \"cc\"]\n[\"one\", \"two\13\&\", \"three\"]3\n&lt;&amp;&gt;\n0x6263Some(\"abc\")\n" )
  , ( "an empty array literal compares with a sequence's array held as a runtime choice, on either side"
    , []
    , Text.unlines
        [ "module Main"
        , "import Std.Iter as Iter"
        , "import Std.Iter {Sequence}"
        , "import Std.Iter.Views as Views"
        , "fn main() -> Int {"
        , "  print(display(Views.join(Iter.items([Iter.empty[Int]()])).toArray() == []))"
        , "  print(display([] == Views.join(Iter.items([Iter.items[Int]([])])).toArray()))"
        , "  print(display(Views.join(Iter.items([Iter.items([1])])).toArray() != []))"
        , "  print(display(Iter.empty[Int]().toArray() == []))"
        , "  0"
        , "}"
        ]
    , "true\ntrue\ntrue\ntrue\n" )
  ]

ledgerAuditRefusals :: [(String, [(FilePath, Text)], Text)]
ledgerAuditRefusals =
  [ ( "integer division by a zero held in a binding stops after earlier output", []
    , Text.unlines
        [ "module Main"
        , "fn main() -> Int { let zero = 0"
        , "  print(\"before\")"
        , "  print(display(10 / zero))"
        , "  0 }"
        ] )
  , ( "Int addition past the maximum stops after earlier output", []
    , Text.unlines
        [ "module Main"
        , "fn main() -> Int { var x = 9223372036854775807"
        , "  print(\"before\")"
        , "  x = x + 1"
        , "  print(display(x))"
        , "  0 }"
        ] )
  , ( "an array index past the end stops", []
    , Text.unlines
        [ "module Main"
        , "fn main() -> Int { let xs = [1, 2, 3]"
        , "  let i = 5"
        , "  print(display(xs[i]))"
        , "  0 }"
        ] )
  , ( "negating the minimum Int stops", []
    , Text.unlines
        [ "module Main"
        , "fn main() -> Int { let m = -9223372036854775807 - 1"
        , "  print(display(-m))"
        , "  0 }"
        ] )
  , ( "a shift by more than the width stops", []
    , Text.unlines
        [ "module Main"
        , "fn main() -> Int { let s = 70"
        , "  print(display(1u64 << s))"
        , "  0 }"
        ] )
  , ( "panic stops after earlier output", []
    , Text.unlines
        [ "module Main"
        , "fn main() -> Int { print(\"a\")"
        , "  panic(\"stop here\")"
        , "  0 }"
        ] )
  , ( "unbounded recursion stops at the call-depth limit after shallower calls finish", []
    , Text.unlines
        [ "module Main"
        , "fn fib(n: Int) -> Int { if n < 2 { n } else { fib(n - 1) + fib(n - 2) } }"
        , "fn ack(m: Int, n: Int) -> Int { if m == 0 { n + 1 } else if n == 0 { ack(m - 1, 1) } else { ack(m - 1, ack(m, n - 1)) } }"
        , "fn even(n: Int) -> Bool { if n == 0 { true } else { odd(n - 1) } }"
        , "fn odd(n: Int) -> Bool { if n == 0 { false } else { even(n - 1) } }"
        , "fn noisy(label: Str, v: Int) -> Int { print(label)"
        , "  v }"
        , "fn three(a: Int, b: Int, c: Int) -> Int { a * 100 + b * 10 + c }"
        , "fn deep(n: Int) -> Int { if n == 0 { 0 } else { 1 + deep(n - 1) } }"
        , "fn main() -> Int {"
        , "  print(display(fib(20)) + \" \" + display(ack(2, 3)) + \" \" + display(even(101)) + display(odd(7)))"
        , "  print(display(three(noisy(\"a\", 1), noisy(\"b\", 2), noisy(\"c\", 3))))"
        , "  let f = three"
        , "  print(display(f(noisy(\"x\", 4), noisy(\"y\", 5), noisy(\"z\", 6))))"
        , "  print(display(deep(1000)))"
        , "  print(display(deep(100000)))"
        , "  0"
        , "}"
        ] )
  ]
