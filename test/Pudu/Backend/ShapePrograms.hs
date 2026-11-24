{-| @Test.Backend.ShapePrograms — record shapes across modules, calls
    through function-valued fields, and assignments used as values. -}
module Pudu.Backend.ShapePrograms (shapeSuccessPrograms, shapeModulePrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

shapeSuccessPrograms :: [(String, Text, Text)]
shapeSuccessPrograms =
  [ ("a record of aliases holding a function, called through its field", program
      [ "type Name = Str", "type Gate = fn(Str) -> Int", "type Holder = { name: Name, admits: Gate }"
      , "", "fn main() -> Int {", "  let held = Holder{name: \"pudu\", admits: fn(reader: Str) -> Int { reader.length() }}"
      , "  print(display(held.name.length() * 10 + (held.admits)(\"abc\")))", "  0", "}" ]
    , "43\n")
  , ("a method of a field's name wins in callee position", program
      [ "type Task = { run: fn(Int) -> Int, name: Str }", "", "trait Runs {"
      , "  fn run(self: Task, n: Int) -> Int", "}", ""
      , "impl Runs for Task {", "  fn run(self: Task, n: Int) -> Int { n + 1000 }", "}"
      , "", "fn noted(n: Int) -> Int {", "  print(\"arg \" + display(n))"
      , "  n", "}", ""
      , "fn main() -> Int {", "  let job = Task{run: |n| n * 2, name: \"t\"}", "  print(display(job.run(noted(3))) + \" \" + display((job.run)(noted(4))))"
      , "  let picked = job.run", "  print(display(picked(5)))", "  0"
      , "}" ]
    , "arg 3\narg 4\n1003 1004\n10\n")
  , ("a function field is selected before its record is rebound", program
      [ "type Holder = { run: fn(Int) -> Int }"
      , "fn main() -> Int {"
      , "  var held = Holder{run: |n| n + 1}"
      , "  print(display(held.run({ held = Holder{run: |n| n + 10}"
      , "    4 })))"
      , "  print(display(held.run(4)))"
      , "  0", "}" ]
    , "5\n14\n")
  , ("records keep selected callable layouts through updates and nested reads", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "fn plain() -> Str { \"plain\" }"
      , "type Runner[T] = { mut action: fn() -> Str, tag: T }"
      , "type Envelope = { mut saved: Runner[Int], pair: (fn() -> Str, Int) }"
      , "fn choose(flag: Bool, action: fn() -> Str) -> Runner[Int] {"
      , "  if flag { Runner{action: plain, tag: 3} } else { Runner{action, tag: 4} }"
      , "}"
      , "fn early(flag: Bool, action: fn() -> Str) -> Runner[Int] {"
      , "  if flag { return Runner{action: plain, tag: 5} }"
      , "  Runner{action, tag: 6}"
      , "}"
      , "fn main() -> Int {"
      , "  let decoded = retain(\"λ\".toBytes())"
      , "  let base = Runner{action: plain, tag: 7}"
      , "  let changed = Runner{..base, action: decoded}"
      , "  var box: Envelope = Envelope{saved: changed, pair: (decoded, 9)}"
      , "  let before = box"
      , "  box.saved.action = plain"
      , "  let first = box.pair[0]"
      , "  print(first())"
      , "  print(box.saved.action())"
      , "  print(before.saved.action())"
      , "  print(base.action())"
      , "  print(choose(false, decoded).action())"
      , "  print(choose(true, decoded).action())"
      , "  print(display(box.saved.tag + box.pair[1]))"
      , "  box = Envelope{saved: early(false, decoded), pair: (plain, 10)}"
      , "  print(box.saved.action())"
      , "  print(display(box.saved.tag + box.pair[1]))"
      , "  0", "}" ]
    , "Some(\"λ\")\nplain\nSome(\"λ\")\nplain\nSome(\"λ\")\nplain\n16\nSome(\"λ\")\n16\n")
  , ("tuple and record match results project to shared native layouts", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "fn plain() -> Str { \"plain\" }"
      , "type Runner = { action: fn() -> Str, number: Int }"
      , "fn check(flag: Bool, decoder: fn() -> Str) {"
      , "  let pair = if flag { (plain, 1) } else { (decoder, 2) }"
      , "  let (action, position) = pair"
      , "  let record = match flag {"
      , "    case true => Runner{action: plain, number: 3}"
      , "    case false => Runner{action: decoder, number: 4}"
      , "  }"
      , "  let selected = match record {"
      , "    case Runner{action: run, number} => (run, number)"
      , "  }"
      , "  let run = selected[0]"
      , "  print(action())"
      , "  print(run())"
      , "  print(display(position + selected[1]))"
      , "  ()"
      , "}"
      , "fn main() -> Int {"
      , "  let decoder = retain(bytesOf([255u8]))"
      , "  check(true, decoder)"
      , "  check(false, decoder)"
      , "  0", "}" ]
    , "plain\nplain\n4\nNone\nNone\n6\n")
  , ("sum constructors and propagation keep the selected callable payload", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "fn plain() -> Str { \"plain\" }"
      , "type Packed = Direct(fn() -> Str) | Named{action: fn() -> Str, name: Str} | Empty"
      , "fn unpack(input: Packed) -> Str {"
      , "  match input {"
      , "    case Direct(run) => display(run())"
      , "    case Named{action, name} => name + display(action())"
      , "    case Empty => \"empty\""
      , "  }"
      , "}"
      , "fn optional(input: Option[fn() -> Str]) -> Option[Str] {"
      , "  let run = input?"
      , "  Some(display(run()))"
      , "}"
      , "fn propagate(input: Result[Int, fn() -> Str]) -> Result[Str, fn() -> Str] {"
      , "  let number = input?"
      , "  Ok(display(number))"
      , "}"
      , "fn main() -> Int {"
      , "  let action = retain(\"λ\".toBytes())"
      , "  print(unpack(Direct(action)))"
      , "  let packed = if false { Direct(plain) } else { Named{action, name: \"held:\"} }"
      , "  print(unpack(packed))"
      , "  print(show(optional(Some(action))))"
      , "  let none: Option[fn() -> Str] = None"
      , "  print(show(optional(none)))"
      , "  let problem: Result[Int, fn() -> Str] = Err(action)"
      , "  let forwarded = propagate(problem)"
      , "  match forwarded {"
      , "    case Ok(message) => print(message)"
      , "    case Err(run) => print(run())"
      , "  }"
      , "  0", "}" ]
    , "Some(\"λ\")\nheld:Some(\"λ\")\nSome(\"Some(\\\"λ\\\")\")\nNone\nSome(\"λ\")\n")
  , ("named and stored async calls preserve deferred native arguments", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "async fn execute(action: fn() -> Str) -> Str {"
      , "  print(\"executing\")"
      , "  action()"
      , "}"
      , "async fn main() -> Result[Int, Str] {"
      , "  let action = retain(\"λ\".toBytes())"
      , "  let run = execute"
      , "  let first = execute(action)"
      , "  let second = run(action)"
      , "  let call = async fn(work: fn() -> Str) -> Str { work() }"
      , "  let third = call(retain(bytesOf([255u8])))"
      , "  print(\"made\")"
      , "  print(first.await)"
      , "  print(second.await)"
      , "  print(third.await)"
      , "  Ok(0)", "}" ]
    , "made\nexecuting\nSome(\"λ\")\nexecuting\nSome(\"λ\")\nNone\n")
  , ("scope joins keep the selected native error and skip the remaining body", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn decode(value: dynamic View) -> Str { value.toText() }"
      , "async fn child() -> Result[Int, Str] {"
      , "  print(\"child\")"
      , "  Err(decode(\"λ\".toBytes()))"
      , "}"
      , "async fn parent() -> Result[Int, Str] {"
      , "  async with scope {"
      , "    let pending = child()"
      , "    print(\"scope\")"
      , "  }"
      , "  print(\"unreached\")"
      , "  Ok(1)"
      , "}"
      , "async fn main() -> Result[Int, Str] {"
      , "  let result = parent().await"
      , "  Ok(result)", "}" ]
    , "scope\nchild\nErr(Some(\"λ\"))\n")
  , ("mutable loan final layouts follow the held field and indexed place", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "fn plain() -> Str { \"plain\" }"
      , "type Holder = { mut action: fn() -> Str }"
      , "fn swap(slot: &mut fn() -> Str, next: fn() -> Str) -> Str {"
      , "  let previous = (*slot)()"
      , "  *slot = next"
      , "  previous"
      , "}"
      , "fn index() -> Int { print(\"index\")\n 0 }"
      , "fn main() -> Int {"
      , "  let decoder = retain(\"λ\".toBytes())"
      , "  var box = Holder{action: decoder}"
      , "  let before = box"
      , "  print(swap(&mut box.action, plain))"
      , "  print(box.action())"
      , "  print(before.action())"
      , "  var items = [decoder, plain]"
      , "  let invoke = swap"
      , "  print(invoke(&mut items[index()], plain))"
      , "  let reset = fn(slot: &mut fn() -> Str) -> Str {"
      , "    let previous = (*slot)()"
      , "    *slot = plain"
      , "    previous"
      , "  }"
      , "  print(reset(&mut items[index()]))"
      , "  let first = items[0]"
      , "  print(first())"
      , "  0", "}" ]
    , "Some(\"λ\")\nplain\nSome(\"λ\")\nindex\nSome(\"λ\")\nindex\nplain\nplain\n")
  , ("mutable slots discover layouts introduced by later writes", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "fn plain() -> Str { \"plain\" }"
      , "type Entry = { mut action: fn() -> Str }"
      , "type Wrapper = { mut entries: Array[Entry] }"
      , "fn index() -> Int { print(\"index\")\n 0 }"
      , "fn replace(slot: &mut fn() -> Str, next: fn() -> Str) { *slot = next }"
      , "fn main() -> Int {"
      , "  let decode = retain(\"λ\".toBytes())"
      , "  var selected = plain"
      , "  let before = selected"
      , "  for step in 0..2 {"
      , "    if step == 0 { selected = decode } else { selected = plain }"
      , "    print(selected())"
      , "  }"
      , "  print(before())"
      , "  let initial = [Entry{action: plain}]"
      , "  var holder = Wrapper{entries: initial}"
      , "  let alias = holder"
      , "  holder.entries[index()].action = decode"
      , "  print(holder.entries[0].action())"
      , "  print(alias.entries[0].action())"
      , "  var borrowed = plain"
      , "  replace(&mut borrowed, decode)"
      , "  print(borrowed())"
      , "  0", "}" ]
    , "Some(\"λ\")\nplain\nplain\nindex\nSome(\"λ\")\nplain\nSome(\"λ\")\n")
  , ("destructured mutable slots settle assignments and loan finals independently", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "fn plain() -> Str { \"plain\" }"
      , "type Holder = { action: fn() -> Str }"
      , "fn replace(slot: &mut fn() -> Str, next: fn() -> Str) { *slot = next }"
      , "fn main() -> Int {"
      , "  let decode = retain(\"λ\".toBytes())"
      , "  var (selected, {action}) = (plain, Holder{action: plain})"
      , "  let original = action"
      , "  selected = decode"
      , "  replace(&mut action, decode)"
      , "  print(selected())"
      , "  print(action())"
      , "  print(original())"
      , "  var [front, ..rest] = [plain, plain]"
      , "  front = decode"
      , "  rest = [decode, plain]"
      , "  print(front())"
      , "  let first = rest[0]"
      , "  let second = rest[1]"
      , "  print(first())"
      , "  print(second())"
      , "  0", "}" ]
    , "Some(\"λ\")\nSome(\"λ\")\nplain\nSome(\"λ\")\nSome(\"λ\")\nplain\n")
  , ("stored loan callables widen finals without replacing their captures", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn retain(value: dynamic View) -> fn() -> Str { value.toText }"
      , "fn plain() -> Str { \"plain\" }"
      , "trait Writes { fn write(self, target: &mut fn() -> Str) }"
      , "type Source = { action: fn() -> Str }"
      , "impl Writes for Source {"
      , "  fn write(self: Source, target: &mut fn() -> Str) { *target = self.action }"
      , "}"
      , "fn main() -> Int {"
      , "  let decoder = retain(\"λ\".toBytes())"
      , "  let install = fn(target: &mut fn() -> Str) { *target = decoder }"
      , "  var first = plain"
      , "  let original = first"
      , "  install(&mut first)"
      , "  print(first())"
      , "  print(original())"
      , "  var source = Source{action: decoder}"
      , "  let write = source.write"
      , "  source = Source{action: plain}"
      , "  var second = plain"
      , "  write(&mut second)"
      , "  print(second())"
      , "  print(source.action())"
      , "  0", "}" ]
    , "Some(\"λ\")\nplain\nSome(\"λ\")\nplain\n")
  , ("shorthand fields naming functions, generic functions and locals", program
      [ "type Plain = { step: fn(Int) -> Int }", "type Boxed[S] = { step: fn(S) -> S, seed: S }"
      , "type Shape = Scaled{ step: fn(Int) -> Int, by: Int } | Flat"
      , "", "fn step(value: Int) -> Int { value + 1 }", "fn same[T](value: T) -> T { value }"
      , "", "fn main() -> Int {"
      , "  let a = Plain{step}", "  let seed = 40", "  let b = Boxed{step, seed}"
      , "  let c = Boxed{..b, step: same}", "  let d = Boxed{..c, step}"
      , "  let picked = Scaled{step, by: 3}"
      , "  let e = match picked {", "    case Scaled{step: run, by} => run(by)", "    case Flat => 0", "  }"
      , "  print(display(a.step(1)) + \" \" + display(b.step(b.seed)) + \" \" + display(c.step(c.seed)) + \" \" + display(d.step(2)) + \" \" + display(e))"
      , "  0", "}" ]
    , "2 41 40 3 4\n")
  , ("mutually recursive records in one module", program
      [ "type Node = { label: Int, parent: Option[Wrap] }", "type Wrap = { node: Node }", ""
      , "fn depth(node: Node) -> Int {", "  match node.parent {", "    case Some(wrapped) => 1 + depth(wrapped.node)"
      , "    case None => 0", "  }", "}"
      , "", "fn main() -> Int {", "  let root = Node{label: 1, parent: None}"
      , "  let child = Node{label: 2, parent: Some(Wrap{node: root})}", "  print(show(child))", "  print(display(depth(child) * 10 + child.label))"
      , "  0", "}" ]
    , "Node{label: 2, parent: Some(Wrap{node: Node{label: 1, parent: None}})}\n12\n")
  , ("assignments used as arm, if-let and binding values", program
      [ "type Box = { mut count: Int }", "", "fn main() -> Int {"
      , "  var parts: Array[Str] = []", "  var box = Box{count: 0}", "  for word in [\"a\", \"\", \"b\"] {"
      , "    match word {", "      case \"\" => box.count = box.count + 1", "      case w => parts = parts.push(w)"
      , "    }", "  }", "  var total = 0"
      , "  let options = [Some(2), None, Some(5)]", "  for o in options {", "    if let Some(n) = o { total = total + n } else { total = total - 1 }"
      , "  }", "  let unit = (total = total * 2)", "  print(show(parts) + \" \" + show(box) + \" \" + display(total) + \" \" + show(unit))"
      , "  return 0", "}" ]
    , "[\"a\", \"b\"] Box{count: 1} 12 ()\n")
  , ("if and match widen dynamic members of their aggregate results", program
      [ "trait Named { fn label(self: &Self) -> Str }"
      , "type LeftWord = { name: Str }"
      , "type RightWord = { labelText: Str }"
      , "impl Named for LeftWord { fn label(self: &Self) -> Str { self.name } }"
      , "impl Named for RightWord { fn label(self: &Self) -> Str { self.labelText } }"
      , "fn select(first: Bool) -> (dynamic Named, Int) {"
      , "  if first { (LeftWord{name: \"left\"}, 1) } else { (RightWord{labelText: \"right\"}, 2) }"
      , "}"
      , "fn optional(first: Bool) -> Option[dynamic Named] {"
      , "  match first {"
      , "    case true => Some(LeftWord{name: \"one\"})"
      , "    case false => Some(RightWord{labelText: \"two\"})"
      , "  }"
      , "}"
      , "fn label(value: Option[dynamic Named]) -> Str {"
      , "  match value {"
      , "    case Some(word) => word.label()"
      , "    case None => \"none\""
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  let (a, x) = select(true)"
      , "  let (b, y) = select(false)"
      , "  print(a.label() + b.label() + display(x + y))"
      , "  print(label(optional(true)) + label(optional(false)))"
      , "  0", "}" ]
    , "leftright3\nonetwo\n")
  , ("concrete widenings admit two instances of a generic implementation", program
      [ "trait Counted { fn amount(self: &Self) -> Int }"
      , "type Box[T] = { payload: T, count: Int }"
      , "impl [T] Counted for Box[T] { fn amount(self: &Self) -> Int { self.count } }"
      , "fn total(items: Array[dynamic Counted]) -> Int {"
      , "  var result = 0"
      , "  for item in items { result = result + item.amount() }"
      , "  result"
      , "}"
      , "fn seal[T](payload: T) -> dynamic Counted { Box{payload, count: 30} }"
      , "fn narrowed(item: dynamic Counted) -> Int {"
      , "  match item {"
      , "    case Box{count} => count"
      , "    case _ => 0"
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  let items: Array[dynamic Counted] = [Box{payload: \"text\", count: 5}, Box{payload: true, count: 12}]"
      , "  print(show(items))"
      , "  print(display(total(items)))"
      , "  print(show(seal(1i8)))"
      , "  print(display(total([seal(1i8)])))"
      , "  print(show((narrowed(items[0]), narrowed(items[1]), narrowed(seal(1i8)))))"
      , "  0", "}" ]
    , "[Box{payload: \"text\", count: 5}, Box{payload: true, count: 12}]\n17\nBox{payload: 1, count: 30}\n30\n(5, 12, 30)\n")
  , ("dynamic keys compare held values across generic layouts", program
      [ "trait Ordered { fn rank(self: &Self) -> Int }"
      , "type Box[T] = { held: T }"
      , "type Choice[T] = Empty | Filled(T)"
      , "impl [T] Ordered for Box[T] { fn rank(self: &Self) -> Int { 0 } }"
      , "impl [T] Ordered for Choice[T] { fn rank(self: &Self) -> Int { 1 } }"
      , "impl Ordered for Int { fn rank(self: &Self) -> Int { 2 } }"
      , "impl Ordered for Int8 { fn rank(self: &Self) -> Int { 3 } }"
      , "fn platform() -> Int { 3 }"
      , "fn main() -> Int {"
      , "  let blank: Array[Int] = []"
      , "  let tiny: Array[Int8] = []"
      , "  let left: dynamic Ordered = Box{held: blank}"
      , "  let right: dynamic Ordered = Box{held: tiny}"
      , "  let wide: dynamic Ordered = Box{held: [platform()]}"
      , "  let narrow: dynamic Ordered = Box{held: [3i8]}"
      , "  let higher: dynamic Ordered = Box{held: [4i8]}"
      , "  let ordinary: dynamic Ordered = platform()"
      , "  let fixed: dynamic Ordered = 3i8"
      , "  let absentText: Choice[Str] = Empty"
      , "  let absentBool: Choice[Bool] = Empty"
      , "  let text: dynamic Ordered = absentText"
      , "  let flag: dynamic Ordered = absentBool"
      , "  print(show((left == right, wide == narrow, ordinary == fixed, text == flag)))"
      , "  print(show(((wide, 0) <= (narrow, 0), (narrow, 0) < (higher, 0), (right, 0) < (wide, 0))))"
      , "  let values = setOf([left, right, wide, narrow, higher, text, flag])"
      , "  print(show((values.size(), values.contains(wide), values.contains(flag))))"
      , "  let tree: dynamic Ordered = Box{held: mapOf([(\"key\", platform())])}"
      , "  let other: dynamic Ordered = Box{held: mapOf([(\"key\", 3i8)])}"
      , "  let emptyInt: Map[Str, Int] = mapOf([])"
      , "  let emptyTiny: Map[Str, Int8] = mapOf([])"
      , "  let firstTree: dynamic Ordered = Box{held: emptyInt}"
      , "  let secondTree: dynamic Ordered = Box{held: emptyTiny}"
      , "  print(show((tree == other, (tree, 0) <= (other, 0), firstTree == secondTree)))"
      , "  0", "}" ]
    , "(true, false, true, true)\n(true, true, true)\n(4, true, true)\n(false, true, true)\n")
  ]

{-| Programs of several modules, each with the files beside its root. -}
shapeModulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
shapeModulePrograms =
  [ ( "records that reach each other across two modules"
    , [ ("Node.pudu", Text.unlines
          [ "module Node", "", "import Wrap {Wrap}"
          , "", "export type Node = { label: Int, parent: Option[Wrap] }", ""
          , "export fn depth(node: Node) -> Int {", "  match node.parent {", "    case Some(wrapped) => 1 + depth(wrapped.node)"
          , "    case None => 0", "  }", "}" ])
      , ("Wrap.pudu", Text.unlines
          [ "module Wrap", "", "import Node {Node}"
          , "", "export type Wrap = { node: Node }", ""
          , "export fn wrap(node: Node) -> Wrap { Wrap{node} }", "", "export fn unwrap(value: Wrap) -> Node { value.node }" ]) ]
    , program
        [ "import Node {Node, depth}", "import Wrap {wrap, unwrap}", ""
        , "fn main() -> Int {", "  let root = Node{label: 1, parent: None}", "  let child = Node{label: 2, parent: Some(wrap(root))}"
        , "  let grandchild = Node{label: 3, parent: Some(wrap(child))}", "  print(display(depth(grandchild) * 10 + unwrap(wrap(grandchild)).label))", "  0"
        , "}" ]
    , "23\n" )
  , ( "a record whose fields are another module's aliases"
    , [ ("Names.pudu", Text.unlines
          [ "module Names", "", "export type Name = Str"
          , "", "export type Gate = fn(Str) -> Int", ""
          , "export fn named() -> Name { \"pudu\" }" ])
      , ("Holder.pudu", Text.unlines
          [ "module Holder", "", "import Names"
          , "", "export type Holder = { name: Names.Name, admits: Names.Gate }" ]) ]
    , program
        [ "import Holder", "import Names", ""
        , "fn main() -> Int {", "  let held = Holder.Holder{name: \"pudu\", admits: fn(reader: Str) -> Int { reader.length() }}", "  let named = Holder.Holder{name: Names.named(), admits: held.admits}"
        , "  let admits = named.admits", "  print(named.name + \" \" + display(held.admits(\"ab\")))", "  print(display(held.name.length() * 10 + admits(\"abc\")))"
        , "  0", "}" ]
    , "pudu 2\n43\n" )
  , ("dynamic patterns narrow by canonical owner before matching the payload"
    , [ ("Contract.pudu", Text.unlines
          [ "module Contract", "export trait Tagged { fn tag(self: &Self) -> Int }" ])
      , provider "First" 1
      , provider "Second" 2 ]
    , program
        [ "import Contract {Tagged}", "import First as A", "import Second as B"
        , "type Holder = { item: dynamic Tagged }"
        , "fn inspect(held: Holder) -> Int {"
        , "  match held {"
        , "    case Holder{item: A.Item{value: 37}} => 100"
        , "    case Holder{item: A.Item{value}} if value > 0 => value + 10"
        , "    case Holder{item: B.Item{value}} => value + 20"
        , "    case _ => 0"
        , "  }"
        , "}"
        , "fn position(value: dynamic Tagged) -> Int {"
        , "  let A.Choice.Pair(held) = value else { return 0 }"
        , "  held"
        , "}"
        , "fn named(value: dynamic Tagged) -> Int {"
        , "  if let B.Choice.Entry{held} = value { held } else { 0 }"
        , "}"
        , "fn main() -> Int {"
        , "  print(show((inspect(Holder{item: A.item()}), inspect(Holder{item: B.item()}))))"
        , "  print(show((position(A.pair()), position(B.pair()))))"
        , "  print(show((named(A.entry()), named(B.entry()))))"
        , "  0", "}" ]
    , "(11, 22)\n(1, 0)\n(0, 2)\n" )
  , ("dynamic method dispatch keeps same-named trait providers distinct"
    , [ ("First.pudu", Text.unlines
          [ "module First", "export trait Named { fn label(self: &Self) -> Str }" ])
      , ("Second.pudu", Text.unlines
          [ "module Second", "export trait Named { fn label(self: &Self) -> Str }" ]) ]
    , program
        [ "import First as A", "import Second as B"
        , "type Item = { labelText: Str }"
        , "impl A.Named for Item { fn label(self: &Self) -> Str { \"first:\" + self.labelText } }"
        , "impl B.Named for Item { fn label(self: &Self) -> Str { \"second:\" + self.labelText } }"
        , "fn first(item: dynamic A.Named) -> Str { item.label() }"
        , "fn second(item: dynamic B.Named) -> Str { item.label() }"
        , "fn main() -> Int {"
        , "  let item = Item{labelText: \"value\"}"
        , "  print(first(item))"
        , "  print(second(item))"
        , "  0", "}" ]
    , "first:value\nsecond:value\n" )
  ]
 where
  provider name value =
    (Text.unpack name <> ".pudu", Text.unlines
      [ "module " <> name
      , "import Contract {Tagged}"
      , "export type Item = { value: Int }"
      , "export type Choice = Pair(Int) | Entry{held: Int}"
      , "impl Tagged for Item { fn tag(self: &Self) -> Int { self.value } }"
      , "impl Tagged for Choice { fn tag(self: &Self) -> Int { 0 } }"
      , "export fn item() -> Item { Item{value: " <> number <> "} }"
      , "export fn pair() -> Choice { Pair(" <> number <> ") }"
      , "export fn entry() -> Choice { Entry{held: " <> number <> "} }" ])
   where
    number = Text.pack (show (value :: Int))

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
