{-| @Test.Backend.RenderingCallablePrograms — rendering values keep builtin semantics. -}
module Pudu.Backend.RenderingCallablePrograms
  ( renderingCallableSuccessPrograms, renderingCallableRefusalPrograms, renderingCallableModulePrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

renderingCallableSuccessPrograms :: [(String, Text, Text, Text)]
renderingCallableSuccessPrograms =
  [
    ("a record-checked read keeps a named variant's held field", program
      (selectedReceiverTypes <>
        [ "type Checked = { value: Int }", "type Payload = Named{value: Str} | Empty" ] <>
        selectedIterable "Checked" "Checked{value: 1}" "Payload" "Named{value: \"held\"}" <>
        [ "fn main() -> Int {"
        , "  let value: Int = choose(\"λ\".toBytes()).items().value"
        , "  print(show(value))"
        , "  0", "}" ])
    , "receiver\nitems\n\"held\"\n", "")
  , ("a record-checked read can retain the held declared method", program
      (selectedReceiverTypes <>
        [ "type Checked = { value: Int }"
        , "type Held = { count: Int }"
        , "trait Read { fn value(self: &Self) -> Int }"
        , "impl Read for Held { fn value(self: &Self) -> Int { self.count } }"
        ] <> selectedIterable "Checked" "Checked{value: 1}" "Held" "Held{count: 4}" <>
        [ "fn main() -> Int {"
        , "  print(show(choose(\"λ\".toBytes()).items().value))"
        , "  0", "}" ])
    , "receiver\nitems\n<fn value>\n", "")
  , ("a field-checked read retains a held builtin method", program
      (selectedReceiverTypes <> ["type Checked = { length: Int }"] <>
        selectedIterable "Checked" "Checked{length: 1}" "Array[Int]" "[4, 7]" <>
        [ "fn main() -> Int {"
        , "  print(show(choose(\"λ\".toBytes()).items().length))"
        , "  0", "}" ])
    , "receiver\nitems\n<array method length>\n", "")
  , ("a stored held builtin uses its receiver and result carrier", heldBuiltinGetProgram
      [ "  var receiver = choose(\"λ\".toBytes()).items()"
      , "  let get = receiver.get"
      , "  receiver = Checked{get: format}"
      , "  print(show(get))"
      , "  print(show(get({ print(\"position\")\n 1 })))" ]
    , "receiver\nitems\n<array method get>\nposition\n7\n", "")
  , ("a checked text method keeps the held range signature", program
      (selectedReceiverTypes <> selectedIterable "Str" "\"hé\"" "Range[Int]" "1..4" <>
        [ "fn main() -> Int {"
        , "  let length = choose(\"λ\".toBytes()).items().length"
        , "  print(show(length))"
        , "  print(show(length()))"
        , "  0", "}" ])
    , "receiver\nitems\n<range method length>\n3\n", "")
  , ("a held traversal uses the checked callback result and held element", program
      (selectedReceiverTypes <>
        [ "type Checked = { map: fn(fn(Int) -> Str) -> Array[Str] }"
        , "fn empty(render: fn(Int) -> Str) -> Array[Str] { [] }" ] <>
        selectedIterable "Checked" "Checked{map: empty}" "Array[Int]" "[4, 7]" <>
        [ "fn main() -> Int {"
        , "  let mapping = choose(\"λ\".toBytes()).items().map"
        , "  print(show(mapping(|n| display(n))))"
        , "  0", "}" ])
    , "receiver\nitems\n[\"4\", \"7\"]\n", "")
  , ("open traversal members can be retained and rendered", program
      (heldOpenTraversalTypes <>
        [ "fn main() -> Int {"
        , "  let receiver = choose(\"λ\".toBytes()).items()"
        , "  print(show(receiver.map))"
        , "  print(show(receiver.reduce))"
        , "  0", "}" ])
    , "receiver\nitems\n<array method map>\n<array method reduce>\n", "")
  , ("open traversals specialize against a later invocation", program
      (heldOpenTraversalTypes <>
        [ "fn checkedMap(run: fn(Int) -> Str) -> Array[Str] { [run(0)] }"
        , "fn checkedReduce(run: fn(Str, Int) -> Str, seed: Str) -> Str { run(seed, 0) }"
        , "trait Read {"
        , "  fn readMap(self: &Self) -> fn(fn(Int) -> Str) -> Array[Str]"
        , "  fn readReduce(self: &Self) -> fn(fn(Str, Int) -> Str, Str) -> Str"
        , "}"
        , "impl Read for Str {"
        , "  fn readMap(self: &Self) -> fn(fn(Int) -> Str) -> Array[Str] { checkedMap }"
        , "  fn readReduce(self: &Self) -> fn(fn(Str, Int) -> Str, Str) -> Str { checkedReduce }"
        , "}"
        , "trait ReadHeld { fn readMap(self: &Self) -> Int\n fn readReduce(self: &Self) -> Int }"
        , "impl ReadHeld for Option[Str] {"
        , "  fn readMap(self: &Self) -> Int { choose(\"λ\".toBytes()).items().map }"
        , "  fn readReduce(self: &Self) -> Int { choose(\"λ\".toBytes()).items().reduce }"
        , "}"
        , "trait EmptyView {"
        , "  fn ints(self: &Self) -> Checked"
        , "  fn texts(self: &Self) -> Checked"
        , "}"
        , "impl EmptyView for Str {"
        , "  fn ints(self: &Self) -> Checked { Checked{map: 1, reduce: 2} }"
        , "  fn texts(self: &Self) -> Checked { Checked{map: 1, reduce: 2} }"
        , "}"
        , "trait HeldEmptyView {"
        , "  fn ints(self: &Self) -> Array[Int]"
        , "  fn texts(self: &Self) -> Array[Str]"
        , "}"
        , "impl HeldEmptyView for Option[Str] {"
        , "  fn ints(self: &Self) -> Array[Int] { [] }"
        , "  fn texts(self: &Self) -> Array[Str] { [] }"
        , "}"
        , "fn main() -> Int {"
        , "  let mapping = choose(\"λ\".toBytes()).readMap()"
        , "  let reducing = choose(\"λ\".toBytes()).readReduce()"
        , "  print(show(mapping(|n| display(n))))"
        , "  print(show(reducing(|acc, n| acc + display(n), \"seed:\")))"
        , "  let render: fn(Int) -> Str = |n| display(n)"
        , "  let empty: Array[fn(Int) -> Str] = []"
        , "  print(show([render].map(mapping)))"
        , "  print(show(empty.map(mapping)))"
        , "  let concrete: fn(fn(Int) -> Str) -> Array[Str] = [4, 7].map"
        , "  let different: fn(fn(Int) -> Str) -> Array[Str] = [7, 4].map"
        , "  print(display(mapping == concrete))"
        , "  print(display(mapping == different))"
        , "  let receiver = choose(\"λ\".toBytes())"
        , "  print(display(receiver.ints().map == receiver.texts().map))"
        , "  0", "}" ])
    , "receiver\nreceiver\nitems\nreceiver\nreceiver\nitems\n[\"4\", \"7\"]\n\"seed:47\"\n[[\"4\", \"7\"]]\n[]\ntrue\nfalse\nreceiver\ntrue\n", "")
  , ("builtin method equality follows the family, member, and receiver", program
      [ "fn main() -> Int {"
      , "  let intMap: Map[Int, Int] = mapOf([])"
      , "  let textMap: Map[Int, Str] = mapOf([])"
      , "  let intSet: Set[Int] = setOf([])"
      , "  let textSet: Set[Str] = setOf([])"
      , "  let intBuckets: Buckets[Int] = bucketsOf()"
      , "  let textBuckets: Buckets[Str] = bucketsOf()"
      , "  print(show((intMap.size == textMap.size, intSet.size == textSet.size, intBuckets.size == textBuckets.size)))"
      , "  print(show((intMap.size == intSet.size, intMap.keys == intMap.values)))"
      , "  let numbers = intMap.insert(1, 2)"
      , "  let words = textMap.insert(1, \"2\")"
      , "  print(show((numbers.size == words.size, numbers.size == intMap.size)))"
      , "  0", "}" ]
    , "(true, true, true)\n(false, false)\n(false, false)\n", "")
  , ("a retained map preserves results from the held callback", program
      (selectedReceiverTypes <> selectedIterable "Int" "1" "Str" "\"held\"" <>
        [ "fn main() -> Int {"
        , "  let mapping: fn(fn(Int) -> Int) -> Array[Int] = [4, 7].map"
        , "  let select: fn(Int) -> Int = |n| { print(display(n))\n choose(\"λ\".toBytes()).items() }"
        , "  print(show(mapping(select)))"
        , "  0", "}" ])
    , "4\nreceiver\nitems\n7\nreceiver\nitems\n[\"held\", \"held\"]\n", "")
  , ("aggregate constructors retain concrete held values and written effects", program
      (selectedReceiverTypes <> selectedIterable "Array[Bool]" "[true]" "Str" "\"x\"" <>
        [ "type Holder = { flag: Bool, count: Int }"
        , "fn main() -> Int {"
        , "  for item in choose(\"λ\".toBytes()).items() {"
        , "    let original = Holder{flag: true, count: 4}"
        , "    let built = Holder{count: { print(\"count\")\n 4 }, flag: { print(\"flag\")\n item }}"
        , "    let changed = Holder{..original, flag: item}"
        , "    print(show((built, changed, original)))"
        , "    print(show([true, item]))"
        , "    print(show([item]))"
        , "    print(show(#{item, false, item}))"
        , "    print(show(setOf([item, item])))"
        , "    print(show(mapOf([(item, item), (false, true), (item, false)])))"
        , "  }"
        , "  0", "}" ])
    , "receiver\nitems\ncount\nflag\n(Holder{flag: 'x', count: 4}, Holder{flag: 'x', count: 4}, Holder{flag: true, count: 4})\n[true, 'x']\n['x']\n#{false, 'x'}\n#{'x'}\n{false: true, 'x': false}\n", "")
  , ("a record update keeps the held owner and evaluates absent-field replacements", program
      (selectedReceiverTypes <>
        [ "type Wanted = { value: Int, missing: Int }"
        , "type Held = { value: Int, spare: Int }"
        ] <> selectedIterable "Wanted" "Wanted{value: 1, missing: 2}" "Held" "Held{value: 3, spare: 4}" <>
        [ "fn main() -> Int {"
        , "  let updated: Wanted = Wanted{..choose(\"λ\".toBytes()).items(), missing: { print(\"missing\")\n 6 }, value: { print(\"value\")\n 7 }}"
        , "  print(show(updated))"
        , "  0", "}" ])
    , "receiver\nitems\nmissing\nvalue\nHeld{value: 7, spare: 4}\n", "")
  , ("a record replacement can transfer before validating its held base", program
      (selectedReceiverTypes <>
        [ "type Wanted = { value: Int }" ] <>
        selectedIterable "Wanted" "Wanted{value: 1}" "Str" "\"not a record\"" <>
        [ "fn finish() -> Int {"
        , "  let updated = Wanted{..choose(\"λ\".toBytes()).items(), value: { print(\"return\")\n return 7 }}"
        , "  print(show(updated))"
        , "  0", "}"
        , "fn main() -> Int { print(show(finish()))\n 0 }" ])
    , "receiver\nitems\nreturn\n7\n", "")
  , ("concrete held arguments enter named, stored and loaned bodies", program
      (selectedReceiverTypes <> selectedIterable "Array[Bool]" "[true]" "Str" "\"x\"" <>
        [ "fn describe(value: Bool) -> Str { show(value) }"
        , "fn peek(slot: &mut Bool) -> Str { show(*slot) }"
        , "fn main() -> Int {"
        , "  let named: fn(Bool) -> Str = describe"
        , "  let prefix = \"captured \""
        , "  let captured = |value: Bool| prefix + show(value)"
        , "  let construct: fn(Bool) -> Option[Bool] = Some"
        , "  let storedLoan: fn(&mut Bool) -> Str = peek"
        , "  for item in choose(\"λ\".toBytes()).items() {"
        , "    print(describe(item))"
        , "    print(named(item))"
        , "    print(captured(item))"
        , "    print(show(construct(item)))"
        , "    var copy = item"
        , "    print(peek(&mut copy))"
        , "    print(storedLoan(&mut copy))"
        , "    print(show(copy))"
        , "  }"
        , "  0", "}" ])
    , "receiver\nitems\n'x'\n'x'\ncaptured 'x'\nSome('x')\n'x'\n'x'\n'x'\n", "")
  , ("concrete held replacements widen local, field and indexed slots", program
      (selectedReceiverTypes <> selectedIterable "Array[Bool]" "[true]" "Str" "\"x\"" <>
        [ "type Holder = { mut flag: Bool }"
        , "fn index() -> Int { print(\"index\")\n 0 }"
        , "fn main() -> Int {"
        , "  var direct = true"
        , "  var holder = Holder{flag: true}"
        , "  var values = [true]"
        , "  let oldHolder = holder"
        , "  let oldValues = values"
        , "  for item in choose(\"λ\".toBytes()).items() {"
        , "    direct = item"
        , "    holder.flag = item"
        , "    values[index()] = item"
        , "  }"
        , "  print(show((direct, holder.flag, values)))"
        , "  print(show((oldHolder.flag, oldValues)))"
        , "  0", "}" ])
    , "receiver\nitems\nindex\n('x', 'x', ['x'])\n(true, [true])\n", "")
  , ("nested positional and named patterns read concrete held fields", program
      (selectedReceiverTypes <>
        [ "type Packet = Pos((Bool, Int)) | Named{pair: (Bool, Int)}" ] <>
        selectedIterable "Array[Bool]" "[true]" "Str" "\"x\"" <>
        [ "fn main() -> Int {"
        , "  for item in choose(\"λ\".toBytes()).items() {"
        , "    let positional = Pos((item, 3))"
        , "    let named = Named{pair: (item, 4)}"
        , "    match positional {"
        , "      case Pos((true, _)) => print(\"checked positional\")"
        , "      case Pos((value, number)) => print(show((value, number)))"
        , "      case _ => print(\"unexpected variant\")"
        , "    }"
        , "    match named {"
        , "      case Named{pair: (true, _)} => print(\"checked named\")"
        , "      case Named{pair: (value, number)} => print(show((value, number)))"
        , "      case _ => print(\"unexpected variant\")"
        , "    }"
        , "  }"
        , "  0", "}" ])
    , "receiver\nitems\n('x', 3)\n('x', 4)\n", "")
  , ("labelled breaks share a layout and keep the selected value", program
      (selectedReceiverTypes <> selectedIterable "Bool" "true" "Str" "\"held\"" <>
        [ "fn displayBreak(early: Bool) -> Str {"
        , "  let value = @outer loop {"
        , "    if early { break @outer false }"
        , "    loop { break @outer choose(\"λ\".toBytes()).items() }"
        , "  }"
        , "  show(value)"
        , "}"
        , "fn main() -> Int {"
        , "  print(displayBreak(true))"
        , "  print(displayBreak(false))"
        , "  0", "}" ])
    , "false\nreceiver\nitems\n\"held\"\n", "")
  , ("a bare break projects unit alongside a held value", program
      (selectedReceiverTypes <> selectedIterable "()" "()" "Str" "\"held\"" <>
        [ "fn displayBreak(early: Bool) -> Str {"
        , "  let value = loop {"
        , "    if early { break }"
        , "    break choose(\"λ\".toBytes()).items()"
        , "  }"
        , "  show(value)"
        , "}"
        , "fn main() -> Int {"
        , "  print(displayBreak(true))"
        , "  print(displayBreak(false))"
        , "  0", "}" ])
    , "()\nreceiver\nitems\n\"held\"\n", "")
  , ("if and match project only the result of the selected branch", program
      (selectedReceiverTypes <> selectedIterable "Bool" "true" "Str" "\"held\"" <>
        [ "fn fromIf(first: Bool) -> Str {"
        , "  let value = if first { print(\"if fixed\")\n true } else { choose(\"λ\".toBytes()).items() }"
        , "  show(value)"
        , "}"
        , "fn fromMatch(first: Bool) -> Str {"
        , "  let value = match first {"
        , "    case true => { print(\"match fixed\")\n false }"
        , "    case false => choose(\"λ\".toBytes()).items()"
        , "  }"
        , "  show(value)"
        , "}"
        , "fn main() -> Int {"
        , "  print(fromIf(true))"
        , "  print(fromIf(false))"
        , "  print(fromMatch(true))"
        , "  print(fromMatch(false))"
        , "  0", "}" ])
    , "if fixed\ntrue\nreceiver\nitems\n\"held\"\nmatch fixed\nfalse\nreceiver\nitems\n\"held\"\n", "")
  , ("held conditions distinguish skipped operands and false guards", heldConditionProgram
      [ "  print(show(false && choose(\"λ\".toBytes()).items()))"
      , "  print(show(true || choose(\"λ\".toBytes()).items()))"
      , "  print(show(true && choose(\"text\").items()))"
      , "  print(show(false || choose(\"\").items()))"
      , "  if choose(\"text\").items() { print(\"taken\") }"
      , "  let value = if choose(\"\").items() { 1 } else { 7 }"
      , "  print(show(value))"
      , "  while choose(\"\").items() { print(\"unreached\") }"
      , "  match 0 {"
      , "    case 0 if choose(\"λ\".toBytes()).items() => print(\"unreached\")"
      , "    case _ => print(\"fell through\")"
      , "  }"
      ]
    , "false\ntrue\nreceiver\nitems\ntrue\nreceiver\nitems\nfalse\nreceiver\nitems\ntaken\nreceiver\nitems\n7\nreceiver\nitems\nreceiver\nitems\nfell through\n", "")
  , ("iteration keeps the layouts and order of a held heterogeneous tuple", program
      (selectedReceiverTypes <> selectedIterable "Array[Int]" "[7, 8]" "(Int, Str, Bool)" "(3, \"four\", true)" <>
        [ "fn main() -> Int {"
        , "  for item in choose(\"λ\".toBytes()).items() { print(show(item)) }"
        , "  0", "}" ])
    , "receiver\nitems\n3\n\"four\"\ntrue\n", "")
  , ("a loop skips incompatible held elements and still reaches later items", program
      (selectedReceiverTypes <> selectedIterable "Array[(Int, Int)]" "[(7, 8)]"
        "(Array[Int], (Int, Int), Array[Int], (Int, Int))" "([1, 2], (3, 4), [5, 6], (7, 8))" <>
        [ "fn main() -> Int {"
        , "  for (first, last) in choose(\"λ\".toBytes()).items() {"
        , "    print(display(first + last))"
        , "  }"
        , "  0", "}" ])
    , "receiver\nitems\n7\n15\n", "")
  , ("an entirely impossible held binder skips the body", program
      (selectedReceiverTypes <> selectedIterable "Array[(Int, Int)]" "[(7, 8)]" "Array[Array[Int]]" "[[1, 2]]" <>
        [ "fn main() -> Int {"
        , "  for (first, _) in choose(\"λ\".toBytes()).items() { print(display(first)) }"
        , "  print(\"done\")"
        , "  0", "}" ])
    , "receiver\nitems\ndone\n", "")
  , ("anonymous record patterns read only matching named payloads", program
      (selectedReceiverTypes <>
        [ "type Checked = { value: Int }"
        , "type Packet = Number{value: Int} | Word{value: Str} | Other{extra: Int} | Bare(Int)"
        ] <> selectedIterable "Array[Checked]" "[Checked{value: 1}]" "Array[Packet]"
          "[Number{value: 2}, Other{extra: 9}, Bare(7), Word{value: \"four\"}]" <>
        [ "fn main() -> Int {"
        , "  let items = choose(\"λ\".toBytes()).items()"
        , "  for {value} in items { print(show(value)) }"
        , "  for item in items {"
        , "    match item {"
        , "      case {value} if { print(\"guard \" + show(value))\n true } => print(\"matched\")"
        , "      case _ => print(\"skipped\")"
        , "    }"
        , "  }"
        , "  0", "}" ])
    , "receiver\nitems\n2\n\"four\"\nguard 2\nmatched\nskipped\nskipped\nguard \"four\"\nmatched\n", "")
  , ("rendering builtin signatures and identities coexist", program
      [ "fn main() -> Int {"
      , "  let integer: fn(Int) -> Str = display"
      , "  let text: fn(Str) -> Str = display"
      , "  let quoted: fn(Str) -> Str = show"
      , "  print(integer(42))"
      , "  print(text(\"raw\"))"
      , "  print(quoted(\"a\\n\"))"
      , "  print(display(integer == display))"
      , "  print(display(text == show))"
      , "  print(show(quoted))"
      , "  0"
      , "}" ]
    , "42\nraw\n\"a\\n\"\ntrue\nfalse\n<builtin show>\n", "")
  , ("stored rendering and output select actual value layouts", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Str { fn size(self: &Self) -> Int { self.length() } }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn decode(value: dynamic View) -> Str { value.toText() }"
      , "fn main() -> Int {"
      , "  let render: fn(Str) -> Str = show"
      , "  let send = print"
      , "  print(render(decode(\"text\")))"
      , "  print(render(decode(\"λ\".toBytes())))"
      , "  send(decode(\"raw\"))"
      , "  send(decode(bytesOf([255u8])))"
      , "  0", "}" ]
    , "\"text\"\nSome(\"λ\")\nraw\nNone\n", "")
  , ("rendering builtins specialize through generic callers", program
      [ "fn render[T](value: T, converter: fn(T) -> Str) -> Str { converter(value) }"
      , "fn main() -> Int {"
      , "  print(display(render(340282366920938463463374607431768211455u128, show) == show(340282366920938463463374607431768211455u128)))"
      , "  print(display(render((), display) == \"()\"))"
      , "  print(display(render(true, show) == \"true\"))"
      , "  print(display(render(1.25f32, show) == show(1.25f32)))"
      , "  print(display(render('é', display) == display('é')))"
      , "  print(display(render([\"a\", \"b\"], show) == show([\"a\", \"b\"])))"
      , "  print(display(render((Some(4), \"x\"), display) == display((Some(4), \"x\"))))"
      , "  0"
      , "}" ]
    , "true\ntrue\ntrue\ntrue\ntrue\ntrue\ntrue\n", "")
  , ("rendering values survive records captures returns and operand effects", program
      [ " type Renderer = { render: fn(Str) -> Str }"
      , "fn choose() -> fn(Str) -> Str { display }"
      , "fn capture(convert: fn(Str) -> Str) -> fn(Str) -> Str { |value| convert(value) }"
      , "fn main() -> Int {"
      , "  let holder = Renderer{render: show}"
      , "  print(holder.render({ print(\"argument\")\n \"held\" }))"
      , "  print(capture(choose())(\"captured\"))"
      , "  let printers: Array[fn(Str) -> Str] = [display, show]"
      , "  for printer in printers { print(printer(\"x\")) }"
      , "  0"
      , "}" ]
    , "argument\n\"held\"\ncaptured\nx\n\"x\"\n", "")
  , ("nearer source and local rendering declarations win", program
      [ "fn display(value: Str) -> Str { \"user:\" + value }"
      , "fn main() -> Int {"
      , "  let render = display"
      , "  print(show(render))"
      , "  print(render(\"x\"))"
      , "  let show: fn(Str) -> Str = |text| \"local:\" + text"
      , "  print(show(\"y\"))"
      , "  0"
      , "}" ]
    , "<fn display>\nuser:x\nlocal:y\n", "")
  , ("selected text keeps its method and index behavior", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\" λ \")"
        , "  let trim = selected.trim"
        , "  print(trim())"
        , "  print(display(selected.length()))"
        , "  print(display(selected[1]))"
        , "  print(selected[1..2])"
        , "  0", "}" ])
    , "receiver\nλ\n3\nλ\nλ\n", "")
  , ("selected text method operands reach direct and stored calls", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  print(\"hello\".replace(choose(\"l\"), { print(\"replacement\")\n \"x\" }))"
        , "  let contains = \"hello\".contains"
        , "  print(display(contains(choose(\"ell\"))))"
        , "  0", "}" ])
    , "receiver\nreplacement\nhexxo\nreceiver\ntrue\n", "")
  , ("argument transfer precedes an incompatible selected layout", program
      (selectedReceiverTypes <>
        [ "fn stop() -> Int {"
        , "  \"hello\".replace(choose(\"λ\".toBytes()), { print(\"transfer\")\n return 7 })"
        , "  99", "}"
        , "fn main() -> Int { print(display(stop()))\n 0 }" ])
    , "receiver\ntransfer\n7\n", "")
  , ("selected text views retain byte offsets and callable identity", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let at = textByteAt"
        , "  print(show(at(choose(\"λ\"), 1)))"
        , "  print(show(textByteSize(choose(\"\"))))"
        , "  print(show(at == textByteAt))"
        , "  0", "}" ])
    , "receiver\nSome(187)\nreceiver\n0\ntrue\n", "")
  , ("selected bytes method operands reach the native method", program
      (selectedReceiverTypes <> selectedByteConversion <>
        [ "fn main() -> Int {"
        , "  print(show(\"head\".toBytes().concat(choose(\"end\").toBytes()).toText()))"
        , "  0", "}" ])
    , "receiver\nSome(\"headend\")\n", "")
  , ("byte construction checks the held array elements in both invocation forms", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedByteArray "Int" "[0, 195, 169]" <>
        [ "fn main() -> Int {"
        , "  let pack = bytesOf"
        , "  print(show(bytesOf(selectedArray(\"ordinary\")).toText()))"
        , "  print(show(pack(selectedArray(\"λ\".toBytes())).toArray()))"
        , "  0", "}" ])
    , "receiver\nSome(\"ordinary\")\nreceiver\n[0, 195, 169]\n", "")
  , ("byte construction accepts an empty held array of another layout", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedByteArray "Bool" "[]" <>
        [ "fn main() -> Int {"
        , "  print(show(bytesOf(selectedArray(\"λ\".toBytes())).length()))"
        , "  0", "}" ])
    , "receiver\n0\n", "")
  , ("wider held integer counts preserve text and byte method results", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let large = selected.indexOf(\"large\")"
        , "  let larger = selected.indexOf(\"larger\")"
        , "  let negative = selected.indexOf(\"negative\")"
        , "  let small = selected.indexOf(\"small\")"
        , "  let take = \"aλz\".take"
        , "  let bytes = \"aλz\".toBytes()"
        , "  let gather = bytes.strided"
        , "  print(show(take(small)) + show(take(large)) + show(\"\".repeat(large)))"
        , "  print(show(\"aλz\".slice(negative, large)) + show(\"aλz\".slice(large, small)))"
        , "  print(show(bytes.at(small)) + show(bytes.at(negative)) + show(bytes.take(large)))"
        , "  print(show(gather(0, larger, large)) + show(gather(0, large, larger)))"
        , "  print(show(bytes.strided(large, 1, 2)) + show(bytes.strided(0, 1, negative)))"
        , "  0", "}" ])
    , "receiver\n\"aλ\"\"aλz\"\"\"\n\"aλz\"\"\"\nSome(187)None0x61cebb7a\nNoneSome(0x61cebb7a)\nSome(0x)None\n", "")
  , ("wider held text-view offsets preserve exact boundaries", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let small = selected.indexOf(\"small\")"
        , "  let large = selected.indexOf(\"large\")"
        , "  let negative = selected.indexOf(\"negative\")"
        , "  let at = textByteAt"
        , "  let slice = textByteSlice"
        , "  print(show(at(\"λx\", small)) + show(at(\"λ\", large)))"
        , "  print(show(slice(\"λx\", small, 3)) + show(slice(\"λx\", negative, small)))"
        , "  print(show(textByteFind(\"λx\", \"\", large)))"
        , "  0", "}" ])
    , "receiver\nSome(120)None\nSome(\"x\")None\nNone\n", "")
  , ("wider held bracket indices select array elements and text scalars", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let position = choose(\"λ\".toBytes()).indexOf(\"small\")"
        , "  print(show([5, 10, 15][position]))"
        , "  print(show(\"λλx\"[position]))"
        , "  0", "}" ])
    , "receiver\n15\n'x'\n", "")
  , ("written slices accept exact wider integer endpoints", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let end = choose(\"λ\".toBytes()).indexOf(\"small\")"
        , "  print(show([1, 2, 3][1..=end]))"
        , "  print(show(\"aλz\"[..end]))"
        , "  print(show(\"aλz\".toBytes()[end..]))"
        , "  0", "}" ])
    , "receiver\n[2, 3]\n\"aλ\"\n0xbb7a\n", "")
  , ("later slice endpoint can transfer before endpoint validation", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn take() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let values = [1, 2, 3]"
        , "  print(show(values[selected.indexOf(\"invalid\")..{ print(\"transfer\")\n return 7 }]))"
        , "  99", "}"
        , "fn main() -> Int { print(show(take()))\n 0 }" ])
    , "receiver\ntransfer\n7\n", "")
  , ("stored ranges retain exact endpoints through queries and traversal", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn bounds(start: Int, end: Int) -> Range[Int] { start..=end }"
        , "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let large = selected.indexOf(\"large\")"
        , "  let larger = selected.indexOf(\"larger\")"
        , "  let range = bounds(large, larger)"
        , "  print(show(range))"
        , "  print(show(range.start()) + show(range.end()) + show(range.length()))"
        , "  print(show(range.contains(large)) + show(range.contains(1)))"
        , "  print(show(range.toArray()) + show(range.reverse()) + show(range.step(2)))"
        , "  print(show((range, 0) < (larger.., 0)))"
        , "  for value in range { print(show(value))\n break }"
        , "  0", "}" ])
    , "receiver\n18446744073709551616..=18446744073709551617\nSome(18446744073709551616)Some(18446744073709551617)2\ntruefalse\n[18446744073709551616, 18446744073709551617][18446744073709551617, 18446744073709551616][18446744073709551616]\ntrue\n18446744073709551616\n", "")
  , ("stored ranges with wider in-bounds endpoints slice normally", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let tail = selected.indexOf(\"small\").."
        , "  print(\"aλz\"[tail])"
        , "  let all = .."
        , "  print(show([1, 2][all]))"
        , "  0", "}" ])
    , "receiver\nz\n[1, 2]\n", "")
  , ("exact range members retain Int through calls and conversions", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn keep(value: Int) -> Int { value }"
        , "fn main() -> Int {"
        , "  let source = choose(\"λ\".toBytes())"
        , "  let large = source.indexOf(\"large\")"
        , "  let decode = charFromCode"
        , "  for member in large..=large {"
        , "    let held = keep(member)"
        , "    print(show(held))"
        , "    print(show(convertInteger[Int](held)) + show(convertInteger[BigInt](held)))"
        , "    print(show(decode(held)))"
        , "    print(show(held &+ 1) + \" \" + show(held >> 1) + \" \" + show(~held))"
        , "  }"
        , "  0", "}" ])
    , "receiver\n18446744073709551616\nNoneSome(18446744073709551616)\nNone\n1 -9223372036854775808 -1\n", "")
  , ("dynamic wide Int members select the Int implementation", program
      (selectedReceiverTypes <> selectedIntegerPositions <> selectedIntegerTrait <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let large = selected.indexOf(\"large\")"
        , "  for member in large..=large {"
        , "    let value = box(member)"
        , "    let kept = value.describe"
        , "    print(kept())"
        , "    print(describe(member))"
        , "  }"
        , "  0", "}" ])
    , "receiver\nInt 18446744073709551616\nInt 18446744073709551616\n", "")
  , ("dynamic exact and narrow Int layouts compare by value", program
      (selectedReceiverTypes <> selectedIntegerPositions <> selectedIntegerTrait <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let low = selected.indexOf(\"small\")"
        , "  let large = selected.indexOf(\"large\")"
        , "  let narrow = box(2)"
        , "  for member in low..large {"
        , "    let held: dynamic Describe = member"
        , "    print(show(held == narrow))"
        , "    print(show(setOf([held, narrow])))"
        , "    print(held.describe())"
        , "    break"
        , "  }"
        , "  0", "}" ])
    , "receiver\ntrue\n#{2}\nInt 2\n", "")
  , ("dynamic wide Int writeback selects the final layout", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "trait Reset { fn reset(self: &mut Self) -> () }"
        , "impl Reset for Int { fn reset(self: &mut Self) -> () { *self = 3 } }"
        , "fn main() -> Int {"
        , "  let large = choose(\"λ\".toBytes()).indexOf(\"large\")"
        , "  for member in large..=large {"
        , "    var held: dynamic Reset = member"
        , "    held.reset()"
        , "    print(show(held))"
        , "  }"
        , "  0", "}" ])
    , "receiver\n3\n", "")
  , ("selected collection uses the held map get result", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedCollection "Map[Int, Str]" "mapOf([(0, \"held\")])" <>
        [ "fn main() -> Int {"
        , "  print(show(chooseCollection(\"A\").get(0)))"
        , "  print(show(chooseCollection(\"λ\".toBytes()).get({ print(\"key\")\n 0 })))"
        , "  0", "}" ])
    , "receiver\n65\nreceiver\nkey\nSome(\"held\")\n", "")
  , ("selected collection uses the held range length and membership", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedCollection "Range[Int]" "2..=4" <>
        [ "fn main() -> Int {"
        , "  let range = chooseCollection(\"λ\".toBytes())"
        , "  print(show(range.length()))"
        , "  print(show(range.contains(4u8)))"
        , "  0", "}" ])
    , "receiver\n3\ntrue\n", "")
  , ("array method positions wrap the held mathematical index", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let large = selected.indexOf(\"large\")"
        , "  let larger = selected.indexOf(\"larger\")"
        , "  let values = [5, 10, 15]"
        , "  let get = values.get"
        , "  print(show(get(large)))"
        , "  print(show(values.insert(larger, 9)))"
        , "  print(show(values.slice(large, larger)))"
        , "  0", "}" ])
    , "receiver\n5\n[5, 9, 10, 15]\n[5]\n", "")
  , ("keyed methods accept a held key outside the checked layout", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let key = choose(\"λ\".toBytes())"
        , "  let initial = mapOf([(\"x\", 3)])"
        , "  print(show(initial.get(key)))"
        , "  print(show(initial.insert(key, 5).get(key)))"
        , "  let values = setOf([\"x\"])"
        , "  print(show(values.contains(key)))"
        , "  print(show(values.insert(key).contains(key)))"
        , "  0", "}" ])
    , "receiver\nNone\nSome(5)\nfalse\ntrue\n", "")
  , ("range step preserves the exact positive stride and selected cardinality", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let large = selected.indexOf(\"large\")"
        , "  let larger = selected.indexOf(\"larger\")"
        , "  let step = (0..=larger).step"
        , "  print(show(step(large)))"
        , "  print(show((1..=5).step(large)))"
        , "  print(show((5..1).step(large)))"
        , "  0", "}" ])
    , "receiver\n[0, 18446744073709551616]\n[1]\n[]\n", "")
  , ("empty array and range do not attempt to invoke a held builtin callback", program
      [ "fn main() -> Int {"
      , "  let empty: Array[Int] = []"
      , "  let render: fn(Int) -> Str = show"
      , "  print(show(empty.map(render)))"
      , "  print(show((2..2).map(render)))"
      , "  0", "}" ]
    , "[]\n[]\n", "")
  , ("range filter discards held non-Boolean predicate results", program
      (selectedReceiverTypes <> selectedPredicate <>
        [ "fn main() -> Int {"
        , "  print(show((1..=2).filter(checkedPredicate)))"
        , "  let empty: Array[Int] = []"
        , "  print(show(empty.filter(checkedPredicate)))"
        , "  0", "}" ])
    , "receiver\npredicate\nreceiver\npredicate\n[]\n[]\n", "")
  , ("declared method selects the held callable result before traversal", program
      (selectedReceiverTypes <> selectedDeclaredCallback "fn(Int) -> Str" "render" <>
        [ "fn render(value: Int) -> Str { \"held \" + display(value) }"
        , "fn main() -> Int {"
        , "  print(show([2].map(choose(\"plain\").callback())))"
        , "  print(show([2].map(choose(\"λ\".toBytes()).callback())))"
        , "  0", "}" ])
    , "receiver\n[3]\nreceiver\n[\"held 2\"]\n", "")
  , ("a declared method value keeps its selected receiver across reassignment", program
      (selectedReceiverTypes <> selectedDeclaredCallback "fn(Int) -> Str" "render" <>
        [ "fn render(value: Int) -> Str { \"held \" + display(value) }"
        , "fn main() -> Int {"
        , "  var selected = choose(\"λ\".toBytes())"
        , "  let captured = selected.callback"
        , "  selected = choose(\"plain\")"
        , "  let fresh = selected.callback"
        , "  print(show([2].map(captured())))"
        , "  print(show([2].map(fresh())))"
        , "  0", "}" ])
    , "receiver\nreceiver\n[\"held 2\"]\n[3]\n", "")
  , ("indirect calls and traversal use the held method's argument count", program
      (selectedReceiverTypes <>
        [ "trait CheckedLabel { fn label(self: &Self, value: Int) -> Str }"
        , "impl CheckedLabel for Str { fn label(self: &Self, value: Int) -> Str { display(value) } }"
        , "fn extra(value: Int) -> Int { print(\"default\")\n value + 2 }"
        , "trait HeldLabel { fn label(self: &Self, value: Int, suffix: Int = extra(value)) -> Str }"
        , "impl HeldLabel for Option[Str] {"
        , "  fn label(self: &Self, value: Int, suffix: Int = extra(value)) -> Str { display(value) + \":\" + display(suffix) }"
        , "}"
        , "fn fixed(first: Int, second: Int, third: Int) -> Str { display(first + second + third) }"
        , "fn applyFixed(run: fn(Int, Int, Int) -> Str) -> Str { run(1, 2, 3) }"
        , "fn main() -> Int {"
        , "  print(applyFixed(fixed))"
        , "  let held = choose(\"λ\".toBytes()).label"
        , "  print(held(4))"
        , "  print(show([5].map(held)))"
        , "  0", "}" ])
    , "6\nreceiver\ndefault\n4:6\ndefault\n[\"5:7\"]\n", "")
  , ("bound member selection returns a held function field unchanged", program
      (selectedReceiverTypes <>
        [ "type Holder = { render: fn(Int) -> Str }"
        , "trait Conversion { fn toBytes(self: &Self) -> Holder }"
        , "impl Conversion for Option[Str] { fn toBytes(self: &Self) -> Holder { Holder{render: renderValue} } }"
        , "trait Render { fn render(self: &Self, value: Int) -> Int }"
        , "impl Render for Bytes { fn render(self: &Self, value: Int) -> Int { value + 1 } }"
        , "fn renderValue(value: Int) -> Str { \"field \" + display(value) }"
        , "fn main() -> Int {"
        , "  let held = choose(\"λ\".toBytes()).toBytes()"
        , "  let selected = held.render"
        , "  print(show(selected(2)))"
        , "  0", "}" ])
    , "receiver\n\"field 2\"\n", "")
  , ("a selected defaulted method writes its exclusive final through an indexed argument", program
      (selectedReceiverTypes <> checkedLoanMethod <>
        [ "fn amount() -> Int { print(\"default\")\n 4 }"
        , "trait HeldShift { fn shift(self: &Self, value: &mut Int, by: Int = amount()) -> Int }"
        , "impl HeldShift for Option[Str] {"
        , "  fn shift(self: &Self, value: &mut Int, by: Int = amount()) -> Int { *value = *value + by\n *value }"
        , "}"
        , "fn main() -> Int {"
        , "  var values = [2]"
        , "  let held = choose(\"λ\".toBytes()).shift"
        , "  print(show(held(&mut values[{ print(\"index\")\n 0 }])))"
        , "  print(show(values))"
        , "  0", "}" ])
    , "receiver\nindex\ndefault\n6\n[6]\n", "")
  , ("a selected method without exclusive parameters leaves the supplied place unchanged", program
      (selectedReceiverTypes <> checkedLoanMethod <>
        [ "trait HeldShift { fn shift(self: &Self, value: Int) -> Int }"
        , "impl HeldShift for Option[Str] { fn shift(self: &Self, value: Int) -> Int { value + 4 } }"
        , "fn main() -> Int {"
        , "  var values = [2]"
        , "  let held = choose(\"λ\".toBytes()).shift"
        , "  print(show(held(&mut values[{ print(\"index\")\n 0 }])))"
        , "  print(show(values))"
        , "  0", "}" ])
    , "receiver\nindex\n6\n[2]\n", "")
  , ("a value-taking checked method can retain a mutable implementation", program
      (selectedReceiverTypes <>
        [ "trait CheckedShift { fn shift(self: &Self, value: Int) -> Int }"
        , "impl CheckedShift for Str { fn shift(self: &Self, value: Int) -> Int { value } }"
        , "trait HeldShift { fn shift(self: &Self, value: &mut Int) -> Int }"
        , "impl HeldShift for Option[Str] {"
        , "  fn shift(self: &Self, value: &mut Int) -> Int { *value = *value + 4\n *value }"
        , "}"
        , "fn pair(value: Int) -> (Int, Int) { (value, value + 100) }"
        , "fn main() -> Int {"
        , "  var value = 2"
        , "  let held = choose(\"λ\".toBytes()).shift"
        , "  print(show(held(value)))"
        , "  print(show(value))"
        , "  print(show(held(value + 1)))"
        , "  print(show(value))"
        , "  let values = [2]"
        , "  print(show(values.map(held)))"
        , "  print(show(values))"
        , "  let ordinary = pair"
        , "  print(show(ordinary(value)))"
        , "  print(show(value))"
        , "  0", "}" ])
    , "receiver\n6\n6\n11\n6\n[6]\n[2]\n(6, 106)\n6\n", "")
  , ("a selected declared call writes back its indexed receiver and argument", program
      (selectedReceiverTypes <> checkedLoanMethod <>
        [ "trait HeldShift { fn shift(self: &mut Self, value: &mut Int) -> Int }"
        , "impl HeldShift for Option[Str] {"
        , "  fn shift(self: &mut Self, value: &mut Int) -> Int {"
        , "    *self = Some(\"changed\")"
        , "    *value = *value + 4"
        , "    *value"
        , "  }"
        , "}"
        , "fn main() -> Int {"
        , "  var receivers = [choose(\"λ\".toBytes())]"
        , "  var values = [2]"
        , "  print(show(receivers[{ print(\"receiver index\")\n 0 }].shift(&mut values[{ print(\"argument index\")\n 0 }])))"
        , "  print(show(receivers))"
        , "  print(show(values))"
        , "  0", "}" ])
    , "receiver\nreceiver index\nargument index\n6\n[Some(\"changed\")]\n[6]\n", "")
  , ("a checked text builtin can select a mutable method on an indexed receiver", program
      (selectedReceiverTypes <>
        [ "trait HeldSearch { fn contains(self: &mut Self, needle: Str) -> Bool }"
        , "impl HeldSearch for Option[Str] {"
        , "  fn contains(self: &mut Self, needle: Str) -> Bool { *self = Some(needle)\n true }"
        , "}"
        , "fn main() -> Int {"
        , "  var values = [choose(\"plain\"), choose(\"λ\".toBytes())]"
        , "  print(show(values[0].contains(\"pl\")))"
        , "  print(show(values[{ print(\"index\")\n 1 }].contains({ print(\"argument\")\n \"changed\" })))"
        , "  print(show(values))"
        , "  0", "}" ])
    , "receiver\nreceiver\ntrue\nindex\nargument\ntrue\n[\"plain\", Some(\"changed\")]\n", "")
  , ("universal text conversion can select a mutable implementation", program
      (selectedReceiverTypes <>
        [ "trait HeldRender { fn toText(self: &mut Self) -> Str }"
        , "impl HeldRender for Option[Str] {"
        , "  fn toText(self: &mut Self) -> Str { *self = Some(\"changed\")\n \"rendered\" }"
        , "}"
        , "fn main() -> Int {"
        , "  var value = choose(\"λ\".toBytes())"
        , "  print(value.toText())"
        , "  print(show(value))"
        , "  0", "}" ])
    , "receiver\nrendered\nSome(\"changed\")\n", "")
  , ("an exact wide integer selects the same element for assignment and mutable calls", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn bump(value: &mut Int) -> Int { *value = *value + 2\n *value }"
        , "trait Touch { fn touch(self: &mut Self) -> Int }"
        , "impl Touch for Int { fn touch(self: &mut Self) -> Int { *self = *self + 5\n *self } }"
        , "fn main() -> Int {"
        , "  var values = [10, 11, 12]"
        , "  let indices = choose(\"λ\".toBytes())"
        , "  let key = indices.indexOf(\"two\")"
        , "  values[key] = { print(\"replacement\")\n 20 }"
        , "  print(show(bump(&mut values[key])))"
        , "  print(show(values[key].touch()))"
        , "  print(show(values))"
        , "  0", "}" ])
    , "receiver\nreplacement\n22\n27\n[10, 11, 27]\n", "")
  , ("a held range selects an array or text slice at a scalar-checked index", program
      (selectedReceiverTypes <> selectedRangeKey <>
        [ "fn main() -> Int {"
        , "  let values = [10, 11, 12, 13]"
        , "  let index = choose(\"λ\".toBytes()).indexOf(\"window\")"
        , "  print(show(values[index]))"
        , "  print(show(\"abcd\"[index]))"
        , "  print(values[{ print(\"key\")\n index }].toText())"
        , "  0", "}" ])
    , "receiver\n[11, 12]\n\"bc\"\nkey\n[11, 12]\n", "")
  , ("a range-checked key can hold an ordinary integer", program
      (selectedReceiverTypes <>
        [ "trait CheckedWindow { fn window(self: &Self) -> Range[Int] }"
        , "impl CheckedWindow for Str { fn window(self: &Self) -> Range[Int] { 0..2 } }"
        , "trait HeldWindow { fn window(self: &Self) -> Int }"
        , "impl HeldWindow for Option[Str] { fn window(self: &Self) -> Int { 2 } }"
        , "fn main() -> Int {"
        , "  let index = choose(\"λ\".toBytes()).window()"
        , "  print(show([10, 11, 12][index]))"
        , "  print(show(\"abcd\"[index]))"
        , "  0", "}" ])
    , "receiver\n12\n'c'\n", "")
  , ("a tuple-checked literal read selects a held array element", program
      (selectedReceiverTypes <> selectedIndexedReceiver "Array[Str]" "[\"first\", \"second\", \"third\"]" <>
        [ "fn main() -> Int {"
        , "  print(show(choose(\"plain\").indexed()[1]))"
        , "  print(show(choose(\"λ\".toBytes()).indexed()[1]))"
        , "  0", "}" ])
    , "receiver\nindexed\n\"tuple\"\nreceiver\nindexed\n\"second\"\n", "")
  , ("a tuple-checked literal read selects a held text scalar", program
      (selectedReceiverTypes <> selectedIndexedReceiver "Str" "\"aλb\"" <>
        [ "fn main() -> Int {"
        , "  let held = choose(\"λ\".toBytes()).indexed()"
        , "  print(show(held[1]))"
        , "  0", "}" ])
    , "receiver\nindexed\n'λ'\n", "")
  , ("tuple destructuring joins successful held binding layouts", program
      (selectedReceiverTypes <> selectedIndexedReceiver "(Int, Int, Bool)" "(7, 8, false)" <>
        [ "fn read(value: dynamic View) -> () {"
        , "  let (_, item, _) = choose(value).indexed()"
        , "  print(show(item))"
        , "  ()"
        , "}"
        , "fn main() -> Int {"
        , "  read(\"plain\")"
        , "  read(\"λ\".toBytes())"
        , "  0", "}" ])
    , "receiver\nindexed\n\"tuple\"\nreceiver\nindexed\n8\n", "")
  , ("a sequence pattern skips its guard when the held receiver is a tuple", program
      (selectedReceiverTypes <> selectedSequenceSubject <>
        [ "fn guard(value: Int) -> Bool { print(\"guard\")\n value == 7 }"
        , "fn read(value: dynamic View) -> Int {"
        , "  match choose(value).parts() {"
        , "    case [item, ..] if guard(item) => item"
        , "    case _ => 0"
        , "  }"
        , "}"
        , "fn main() -> Int {"
        , "  print(show(read(\"plain\")))"
        , "  print(show(read(\"λ\".toBytes())))"
        , "  0", "}" ])
    , "receiver\nguard\n7\nreceiver\n0\n", "")
  , ("nested pattern alternatives project the held binding before the guard", program
      (selectedReceiverTypes <> selectedEscapingSubject "[\"held\"]" <>
        [ "fn decide(item: Int) -> Bool { print(show(item))\n show(item) == \"7\" }"
        , "fn read(value: dynamic View) -> Int {"
        , "  match (choose(value).items(), true) {"
        , "    case ([item] | [item, _, ..], true) if decide(item) => item"
        , "    case _ => 0"
        , "  }"
        , "}"
        , "fn main() -> Int {"
        , "  print(show(read(\"plain\")))"
        , "  print(show(read(\"λ\".toBytes())))"
        , "  0", "}" ])
    , "receiver\n7\n7\nreceiver\n\"held\"\n0\n", "")
  , ("nested sequence alternatives publish into the scope after let else", program
      (selectedReceiverTypes <> selectedEscapingSubject "[\"held\"]" <>
        [ "fn read(value: dynamic View) -> Int {"
        , "  let ([item] | [item, _, ..], true) = (choose(value).items(), true) else { return 9 }"
        , "  print(show(item))"
        , "  0"
        , "}"
        , "fn main() -> Int {"
        , "  read(\"plain\")"
        , "  read(\"λ\".toBytes())"
        , "  0", "}" ])
    , "receiver\n7\nreceiver\n\"held\"\n", "")
  , ("let else publishes values across distinct held element layouts", program
      (selectedReceiverTypes <> selectedEscapingSubject "[\"held\", \"tail\"]" <>
        [ "fn read(value: dynamic View) -> Int {"
        , "  let [first, ..rest] = choose(value).items() else { return 9 }"
        , "  print(show(first))"
        , "  print(show(rest))"
        , "  0"
        , "}"
        , "fn main() -> Int {"
        , "  print(show(read(\"plain\")))"
        , "  print(show(read(\"λ\".toBytes())))"
        , "  0", "}" ])
    , "receiver\n7\n[8]\n0\nreceiver\n\"held\"\n[\"tail\"]\n0\n", "")
  , ("let else falls back before publishing failed bindings", program
      (selectedReceiverTypes <> selectedEscapingSubject "[]" <>
        [ "fn read(value: dynamic View) -> Int {"
        , "  let first = 9"
        , "  let [first, ..] = choose(value).items() else { return first }"
        , "  first"
        , "}"
        , "fn main() -> Int {"
        , "  print(show(read(\"plain\")))"
        , "  print(show(read(\"λ\".toBytes())))"
        , "  0", "}" ])
    , "receiver\n7\nreceiver\n9\n", "")
  , ("a selected declared call can reach a held collection builtin", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedCollection "Map[Int, Str]" "mapOf([(0, \"held\")])" <>
        [ "trait Keys { fn keys(self: &Self) -> Array[UInt8] }"
        , "impl Keys for Array[UInt8] { fn keys(self: &Self) -> Array[UInt8] { *self } }"
        , "fn main() -> Int {"
        , "  print(show(chooseCollection(\"A\").keys()))"
        , "  print(show(chooseCollection(\"λ\".toBytes()).keys()))"
        , "  0", "}" ])
    , "receiver\n[65]\nreceiver\n[0]\n", "")
  , ("rendering function arguments use callable rendering", program
      [ "fn main() -> Int {"
      , "  let repr: fn(fn(Int) -> Str) -> Str = show"
      , "  let render: fn(Int) -> Str = display"
      , "  print(repr(render))"
      , "  0"
      , "}" ]
    , "<builtin display>\n", "")
  , ("rendering builtin entry reports its tag", program
      [ "fn main() -> fn(Int) -> Str { display }" ]
    , "<builtin display>\n", "")
  , ("owned display identity retains and releases text results", program
      [ "fn main() -> Int {"
      , "  let convert: fn(Str) -> Str = display"
      , "  var text = \"x\".repeat(8192)"
      , "  for index in 0..40 { text = convert(text) }"
      , "  print(show(text.length()))"
      , "  0"
      , "}" ]
    , "8192\n", "")
  , ("rendering argument transfer bypasses the builtin invocation", program
      [ "fn stop() -> Int {"
      , "  let render: fn(Int) -> Str = show"
      , "  render({ print(\"transfer\")\n return 7 })"
      , "  99", "}"
      , "fn main() -> Int { print(display(stop()))\n 0 }" ]
    , "transfer\n7\n", "")
  , ("rendering builtin does not descend at the source depth limit", deep
      [ "fn main() -> Int { print(descend(" <> number (callDepthLimit - 1) <> ", display))\n 0 }" ]
    , "7\n", "")
  ]

renderingCallableRefusalPrograms :: [(String, Text)]
renderingCallableRefusalPrograms =
  [
    ("a record read reports the missing field against the held record owner", heldFieldProgram
      [ "type Other = { extra: Int }" ] "Other" "Other{extra: 7}")
  , ("a named sum read reports the missing field against the sum owner", heldFieldProgram
      [ "type Other = Named{extra: Int} | Empty" ] "Other" "Named{extra: 7}")
  , ("a record read on a held tuple reports its receiver kind", heldFieldProgram
      [] "(Int, Int)" "(3, 4)")
  , ("a selected builtin failure blames the saved call", heldBuiltinGetProgram
      [ "  let get = choose(\"λ\".toBytes()).items().get"
      , "  print(show(get({ print(\"position\")\n 2 })))" ])
  , ("a held array callable checks its own count after all arguments", program
      (selectedReceiverTypes <>
        [ "type Checked = { get: fn(Int, Int) -> Int }"
        , "fn combine(first: Int, second: Int) -> Int { first + second }" ] <>
        selectedIterable "Checked" "Checked{get: combine}" "Array[Int]" "[4, 7]" <>
        [ "fn main() -> Int {"
        , "  let get = choose(\"λ\".toBytes()).items().get"
        , "  print(show(get({ print(\"first\")\n 0 }, { print(\"second\")\n 1 })))"
        , "  0", "}" ]))
  , ("a held byte callable reports its missing argument after supplied effects", program
      (selectedReceiverTypes <>
        [ "type Checked = { slice: fn(Int) -> Int }"
        , "fn supplied(value: Int) -> Int { value }" ] <>
        selectedIterable "Checked" "Checked{slice: supplied}" "Bytes" "\"bytes\".toBytes()" <>
        [ "fn main() -> Int {"
        , "  let slice = choose(\"λ\".toBytes()).items().slice"
        , "  print(show(slice({ print(\"start\")\n 1 })))"
        , "  0", "}" ]))
  , ("a record update reports a held non-record after the written fields", program
      (selectedReceiverTypes <>
        [ "type Wanted = { first: Int, second: Int }" ] <>
        selectedIterable "Wanted" "Wanted{first: 1, second: 2}" "Str" "\"not a record\"" <>
        [ "fn main() -> Int {"
        , "  let updated = Wanted{..choose(\"λ\".toBytes()).items(), second: { print(\"second\")\n 4 }, first: { print(\"first\")\n 3 }}"
        , "  print(show(updated))"
        , "  0", "}" ]))
  , ("a held non-Bool if condition reports before either branch", heldConditionProgram
      [ "  let chosen = if choose(\"λ\".toBytes()).items() { \"left\" } else { \"right\" }"
      , "  print(chosen)"
      ])
  , ("a held non-Bool while condition reports before its body", heldConditionProgram
      [ "  while choose(\"λ\".toBytes()).items() { print(\"unreached\") }" ])
  , ("an invalid held left operand stops before the logical right operand", heldConditionProgram
      [ "  print(show(choose(\"λ\".toBytes()).items() && { print(\"unreached\")\n true }))" ])
  , ("an invalid held right operand fails only on the taken logical path", heldConditionProgram
      [ "  print(show({ print(\"left\")\n false } || choose(\"λ\".toBytes()).items()))" ])
  , ("rendering builtin unary failures name builtin", program
      [ "fn main() -> Int { let renderer: fn(Int) -> Str = show\n let invalid = -renderer\n print(display(invalid))\n 0 }" ])
  , ("rendering builtin ordering is refused after operand effects", program
      [ "fn left() -> fn(Int) -> Str { print(\"left\")\n display }"
      , "fn right() -> fn(Int) -> Str { print(\"right\")\n show }"
      , "fn main() -> Int { let invalid = left() < right()\n print(display(invalid))\n 0 }" ])
  , ("selected missing method fails before evaluating arguments", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  print(display(selected.contains({ print(\"unreached\")\n \"λ\" })))"
        , "  0", "}" ]))
  , ("selected missing bound method fails when retained", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let selected = choose(bytesOf([255u8]))"
        , "  let kept = selected.trim"
        , "  print(kept())"
        , "  0", "}" ]))
  , ("selected invalid numeric index still evaluates the key", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  print(display(selected[{ print(\"index\")\n 0 }]))"
        , "  0", "}" ]))
  , ("selected invalid slice still evaluates both ends", program
      (selectedReceiverTypes <>
        [ "fn bound(label: Str, value: Int) -> Int { print(label)\n value }"
        , "fn main() -> Int {"
        , "  let selected = choose(bytesOf([255u8]))"
        , "  print(selected[bound(\"start\", 0)..bound(\"end\", 1)])"
        , "  0", "}" ]))
  , ("selected invalid text operand keeps later operand effects", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  print(\"hello\".replace(choose(\"λ\".toBytes()), { print(\"replacement\")\n \"x\" }))"
        , "  0", "}" ]))
  , ("selected invalid bound text operand names the invocation", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let contains = \"hello\".contains"
        , "  print(display(contains(choose(\"λ\".toBytes()))))"
        , "  0", "}" ]))
  , ("selected invalid byte operand uses the byte method diagnostic", program
      (selectedReceiverTypes <> selectedByteConversion <>
        [ "fn main() -> Int {"
        , "  print(show(\"head\".toBytes().concat(choose(\"λ\".toBytes()).toBytes())))"
        , "  0", "}" ]))
  , ("selected text view operands fail after evaluating offsets", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  print(show(textByteAt(choose(\"λ\".toBytes()), { print(\"offset\")\n 0 })))"
        , "  0", "}" ]))
  , ("selected stored text view failure names the invocation", program
      (selectedReceiverTypes <>
        [ "fn main() -> Int {"
        , "  let at = textByteAt"
        , "  print(show(at(choose(\"λ\".toBytes()), { print(\"offset\")\n 0 })))"
        , "  0", "}" ]))
  , ("byte construction reports the first out-of-range held integer", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedByteArray "Int" "[0, -1, 256]" <>
        [ "fn main() -> Int {"
        , "  let pack = bytesOf"
        , "  print(show(pack(selectedArray(\"λ\".toBytes()))))"
        , "  0", "}" ]))
  , ("byte construction refuses a held noninteger element", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedByteArray "Bool" "[false]" <>
        [ "fn main() -> Int {"
        , "  print(show(bytesOf(selectedArray(\"λ\".toBytes()))))"
        , "  0", "}" ]))
  , ("wider held repeat count fails at the stored invocation", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let repeat = \"word\".repeat"
        , "  print(repeat(choose(\"λ\".toBytes()).indexOf(\"large\")))"
        , "  0", "}" ]))
  , ("wider negative text count keeps the negative-count diagnostic", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  print(\"word\".take(choose(\"λ\".toBytes()).indexOf(\"negative\")))"
        , "  0", "}" ]))
  , ("wider held bracket index reports an out-of-range key", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let numbers = [5, 10, 15]"
        , "  print(show(numbers[choose(\"λ\".toBytes()).indexOf(\"large\")]))"
        , "  0", "}" ]))
  , ("written slice keeps the exact bound above Int", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  print(show(\"λz\"[..selected.indexOf(\"large\")]))"
        , "  0", "}" ]))
  , ("written slice reports the earlier incompatible endpoint after both effects", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  print(show([1, 2][{ print(\"start\")\n selected.indexOf(\"invalid\") }..{ print(\"end\")\n 1 }]))"
        , "  0", "}" ]))
  , ("written slice checks endpoint kind before the held receiver", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  print(show(selected[..selected.indexOf(\"invalid\")]))"
        , "  0", "}" ]))
  , ("stored slice reads a wide endpoint without wrapping", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let end = choose(\"λ\".toBytes()).indexOf(\"large\")"
        , "  let key = ..end"
        , "  print(show([1, 2][key]))"
        , "  0", "}" ]))
  , ("stored range construction keeps both effects before validating the first end", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  let bad = { print(\"start\")\n selected.indexOf(\"invalid\") }..{ print(\"end\")\n 1 }"
        , "  print(show(bad))"
        , "  0", "}" ]))
  , ("exact stored range sum reports overflow on the final result", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let large = choose(\"λ\".toBytes()).indexOf(\"large\")"
        , "  let one = large..=large"
        , "  print(show(one.sum()))"
        , "  0", "}" ]))
  , ("arithmetic on a wide range member still checks Int overflow", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn add(value: Int) -> Int { value + 1 }"
        , "fn main() -> Int {"
        , "  let large = choose(\"λ\".toBytes()).indexOf(\"large\")"
        , "  for member in large..=large { print(show(add(member))) }"
        , "  0", "}" ]))
  , ("a dynamic wide Int method keeps its checked overflow", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "trait Step { fn step(self: &Self) -> Int }"
        , "impl Step for Int { fn step(self: &Self) -> Int { *self + 1 } }"
        , "fn main() -> Int {"
        , "  let large = choose(\"λ\".toBytes()).indexOf(\"large\")"
        , "  for member in large..=large {"
        , "    let held: dynamic Step = member"
        , "    print(show(held.step()))"
        , "  }"
        , "  0", "}" ]))
  , ("missing member on a held map stops before the argument", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedCollection "Map[Int, Str]" "mapOf([(0, \"held\")])" <>
        [ "fn main() -> Int {"
        , "  let selected = chooseCollection(\"λ\".toBytes())"
        , "  print(show(selected.push({ print(\"unreached\")\n 1u8 })))"
        , "  0", "}" ]))
  , ("missing member on a held range stops before the argument", program
      (selectedReceiverTypes <> selectedByteConversion <> selectedCollection "Range[Int]" "2..=4" <>
        [ "fn main() -> Int {"
        , "  let selected = chooseCollection(\"λ\".toBytes())"
        , "  print(show(selected.get({ print(\"unreached\")\n 0 })))"
        , "  0", "}" ]))
  , ("array method wrong held position reports at the stored invocation", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn main() -> Int {"
        , "  let insert = [1, 2].insert"
        , "  let position = choose(\"λ\".toBytes()).indexOf(\"invalid\")"
        , "  print(show(insert(position, { print(\"item\")\n 3 })))"
        , "  0", "}" ]))
  , ("range step rejects a held noninteger with its method diagnostic", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn main() -> Int {"
        , "  let position = choose(\"λ\".toBytes()).indexOf(\"invalid\")"
        , "  print(show((1..5).step(position)))"
        , "  0", "}" ]))
  , ("range step checks the exact sign before requiring endpoints", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  let stride = choose(\"λ\".toBytes()).indexOf(\"negative\")"
        , "  print(show((1..).step(stride)))"
        , "  0", "}" ]))
  , ("array traversal reports a held builtin when it is invoked", program
      [ "fn main() -> Int {"
      , "  let render: fn(Int) -> Str = show"
      , "  let map: fn(fn(Int) -> Str) -> Array[Str] = [1].map"
      , "  print(show(map({ print(\"callback\")\n render })))"
      , "  0", "}" ])
  , ("array filter reports a held non-Boolean predicate after its effects", program
      (selectedReceiverTypes <> selectedPredicate <>
        [ "fn main() -> Int {"
        , "  print(show([1, 2].filter(checkedPredicate)))"
        , "  0", "}" ]))
  , ("array sort reports a held non-Boolean comparison at the invocation", program
      (selectedReceiverTypes <> selectedPredicate <>
        [ "fn compare(left: Int, right: Int) -> Bool { checkedPredicate(left) }"
        , "fn main() -> Int {"
        , "  let sort = [2, 1].sortBy"
        , "  print(show(sort(compare)))"
        , "  0", "}" ]))
  , ("declared member missing on the held receiver stops before argument effects", program
      (selectedReceiverTypes <>
        [ "trait Announce { fn announce(self: &Self, label: Str) -> Str }"
        , "impl Announce for Str { fn announce(self: &Self, label: Str) -> Str { label } }"
        , "fn main() -> Int {"
        , "  let selected = choose(\"λ\".toBytes())"
        , "  print(selected.announce({ print(\"unreached\")\n \"label\" }))"
        , "  0", "}" ]))
  , ("a missing bound member fails at capture before a later statement", program
      (selectedReceiverTypes <>
        [ "trait Announce { fn announce(self: &Self, label: Str) -> Str }"
        , "impl Announce for Str { fn announce(self: &Self, label: Str) -> Str { label } }"
        , "fn main() -> Int {"
        , "  let captured = choose(\"λ\".toBytes()).announce"
        , "  print(\"unreached\")"
        , "  print(captured(\"label\"))"
        , "  0", "}" ]))
  , ("selected declared callback reports its actual missing parameter", program
      (selectedReceiverTypes <> selectedDeclaredCallback "fn(Int, Str) -> Int" "longer" <>
        [ "fn longer(value: Int, missing: Str) -> Int { value }"
        , "fn main() -> Int {"
        , "  let callback = choose(\"λ\".toBytes()).callback()"
        , "  print(show([1].map(callback)))"
        , "  0", "}" ]))
  , ("a selected indirect callable names its missing parameter after argument effects", program
      (selectedReceiverTypes <> selectedDeclaredCallback "fn(Int, Str) -> Int" "longer" <>
        [ "fn longer(value: Int, missing: Str) -> Int { value }"
        , "fn main() -> Int {"
        , "  let callback = choose(\"λ\".toBytes()).callback()"
        , "  print(show(callback({ print(\"argument\")\n 1 })))"
        , "  0", "}" ]))
  , ("a selected loaned callable names the missing parameter after reading the place", program
      (selectedReceiverTypes <> checkedLoanMethod <>
        [ "trait HeldShift { fn shift(self: &Self, value: &mut Int, amount: Int) -> Int }"
        , "impl HeldShift for Option[Str] {"
        , "  fn shift(self: &Self, value: &mut Int, amount: Int) -> Int { print(\"unreached\")\n *value + amount }"
        , "}"
        , "fn main() -> Int {"
        , "  var values = [2]"
        , "  let held = choose(\"λ\".toBytes()).shift"
        , "  print(show(held(&mut values[{ print(\"index\")\n 0 }])))"
        , "  0", "}" ]))
  , ("a wide assignment key checks bounds after the replacement runs", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn main() -> Int {"
        , "  var values = [0, 1]"
        , "  let indices = choose(\"λ\".toBytes())"
        , "  values[indices.indexOf(\"large\")] = { print(\"replacement\")\n 3 }"
        , "  0", "}" ]))
  , ("a negative wide key fails when preparing a mutable argument", program
      (selectedReceiverTypes <> selectedIntegerPositions <>
        [ "fn bump(value: &mut Int) -> Int { print(\"unreached\")\n *value }"
        , "fn main() -> Int {"
        , "  var values = [0, 1]"
        , "  let indices = choose(\"λ\".toBytes())"
        , "  print(show(bump(&mut values[indices.indexOf(\"negative\")])))"
        , "  0", "}" ]))
  , ("a selected noninteger key reports the assignment diagnostic after the replacement", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn main() -> Int {"
        , "  var values = [0]"
        , "  let indices = choose(\"λ\".toBytes())"
        , "  values[indices.indexOf(\"invalid\")] = { print(\"replacement\")\n 3 }"
        , "  0", "}" ]))
  , ("an outer bounds failure precedes an invalid selected key in a nested store", program
      (selectedReceiverTypes <> selectedInvalidPosition <>
        [ "fn main() -> Int {"
        , "  var values = [[0]]"
        , "  let indices = choose(\"λ\".toBytes())"
        , "  values[{ print(\"outer\")\n 99 }][{ print(\"inner\")\n indices.indexOf(\"invalid\") }] = { print(\"replacement\")\n 3 }"
        , "  0", "}" ]))
  , ("a mutable argument reads its held slice before writeback refuses the range key", program
      (selectedReceiverTypes <> selectedRangeKey <>
        [ "fn inspect(value: &mut Int) -> Int { print(show(*value))\n 7 }"
        , "fn main() -> Int {"
        , "  var values = [10, 11, 12, 13]"
        , "  let index = choose(\"λ\".toBytes()).indexOf(\"window\")"
        , "  print(show(inspect(&mut values[index])))"
        , "  0", "}" ]))
  , ("a noniterable held value fails after effects from the source", program
      (selectedReceiverTypes <> selectedIterable "Array[Int]" "[7, 8]" "Int" "42" <>
        [ "fn main() -> Int {"
        , "  for item in choose(\"λ\".toBytes()).items() { print(display(item)) }"
        , "  0", "}" ]))
  , ("a sequence pattern reports the held named variant when its field is absent", program
      (selectedReceiverTypes <>
        [ "type Checked = { values: Array[Int] }"
        , "type Packet = Items{values: Array[Int]} | Other{extra: Int}"
        ] <> selectedIterable "Checked" "Checked{values: [1]}" "Packet" "Other{extra: 7}" <>
        [ "fn main() -> Int {"
        , "  let {values: [first, ..]} = choose(\"λ\".toBytes()).items()"
        , "  print(show(first))"
        , "  0", "}" ]))
  , ("a shorter held tuple reports bounds after evaluating the receiver", program
      (selectedReceiverTypes <> selectedIndexedReceiver "(Int, Int)" "(1, 2)" <>
        [ "fn main() -> Int {"
        , "  print(show(choose(\"λ\".toBytes()).indexed()[2]))"
        , "  0", "}" ]))
  , ("tuple destructuring reports the held array at the whole pattern", program
      (selectedReceiverTypes <> selectedIndexedReceiver "Array[Int]" "[1, 2, 3]" <>
        [ "fn main() -> Int {"
        , "  let (first, _, _) = choose(\"λ\".toBytes()).indexed()"
        , "  print(show(first))"
        , "  0", "}" ]))
  , ("a sequence binding reports the held tuple as its subject", program
      (selectedReceiverTypes <> selectedSequenceSubject <>
        [ "fn main() -> Int {"
        , "  let [first, ..] = choose(\"λ\".toBytes()).parts()"
        , "  print(show(first))"
        , "  0", "}" ]))
  , ("a missing field on the held record reports its runtime kind", program
      (selectedReceiverTypes <>
        [ "type Checked = { value: Int }"
        , "type Held = { other: Str }"
        , "trait CheckedShape { fn shaped(self: &Self) -> Checked }"
        , "impl CheckedShape for Str { fn shaped(self: &Self) -> Checked { Checked{value: 1} } }"
        , "trait HeldShape { fn shaped(self: &Self) -> Held }"
        , "impl HeldShape for Option[Str] { fn shaped(self: &Self) -> Held { Held{other: \"held\"} } }"
        , "fn main() -> Int {"
        , "  let {value} = choose(\"λ\".toBytes()).shaped()"
        , "  print(show(value))"
        , "  0", "}" ]))
  , ("a stored stopping builtin receives the held runtime argument", program
      [ "trait View { fn size(self: &Self) -> Int }"
      , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
      , "fn decode(value: dynamic View) -> Str { print(\"argument\")\n value.toText() }"
      , "fn main() -> Int {"
      , "  let stop: fn(Str) -> Never = panic"
      , "  stop(decode(\"λ\".toBytes()))"
      , "}" ])
  , ("rendering builtin map keys retain runtime refusal", program
      [ "fn main() -> Int { let renderer: fn(Int) -> Str = show\n let invalid = mapOf([(renderer, 1)])\n print(display(invalid))\n 0 }" ])
  , ("rendering callable arguments fail before dispatch", program
      [ "fn main() -> Int { let renderer: fn(Int) -> Str = show\n print(renderer({ print(\"argument\")\n 1 / 0 }))\n 0 }" ])
  , ("source rendering callable still descends at the same boundary", deep
      [ "fn custom(value: Int) -> Str { display(value) }"
      , "fn main() -> Int { print(descend(" <> number (callDepthLimit - 1) <> ", custom))\n 0 }" ])
  ]

deep :: [Text] -> Text
deep body = program
  ([ "fn descend(n: Int, render: fn(Int) -> Str) -> Str {"
   , "  if n == 0 { return render(7) }", "  descend(n - 1, render)", "}" ] <> body)

number :: Int -> Text
number = Text.pack . show

selectedReceiverTypes :: [Text]
selectedReceiverTypes =
  [ "trait View { fn size(self: &Self) -> Int }"
  , "impl View for Str { fn size(self: &Self) -> Int { self.length() } }"
  , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
  , "fn choose(value: dynamic View) -> Str {"
  , "  print(\"receiver\")"
  , "  value.toText()"
  , "}"
  ]

selectedIterable :: Text -> Text -> Text -> Text -> [Text]
selectedIterable checked checkedBody held heldBody =
  [ "trait CheckedIterable { fn items(self: &Self) -> " <> checked <> " }"
  , "impl CheckedIterable for Str {"
  , "  fn items(self: &Self) -> " <> checked <> " { print(\"items\")\n " <> checkedBody <> " }"
  , "}"
  , "trait HeldIterable { fn items(self: &Self) -> " <> held <> " }"
  , "impl HeldIterable for Option[Str] {"
  , "  fn items(self: &Self) -> " <> held <> " { print(\"items\")\n " <> heldBody <> " }"
  , "}"
  ]

heldConditionProgram :: [Text] -> Text
heldConditionProgram body = program
  (selectedReceiverTypes <> selectedIterable "Bool" "self.length() > 0" "Str" "\"wrong\"" <>
    ["fn main() -> Int {"] <> body <> ["  0", "}"])

heldFieldProgram :: [Text] -> Text -> Text -> Text
heldFieldProgram declarations held heldBody = program
  (selectedReceiverTypes <> ["type Checked = { value: Int }"] <> declarations <>
    selectedIterable "Checked" "Checked{value: 1}" held heldBody <>
    [ "fn main() -> Int {"
    , "  print(show(choose(\"λ\".toBytes()).items().value))"
    , "  0", "}" ])

heldBuiltinGetProgram :: [Text] -> Text
heldBuiltinGetProgram statements = program
  (selectedReceiverTypes <>
    [ "type Checked = { get: fn(Int) -> Str }"
    , "fn format(value: Int) -> Str { display(value) }" ] <>
    selectedIterable "Checked" "Checked{get: format}" "Array[Int]" "[4, 7]" <>
    ["fn main() -> Int {"] <> statements <> ["  0", "}"])

heldOpenTraversalTypes :: [Text]
heldOpenTraversalTypes = selectedReceiverTypes <> ["type Checked = { map: Int, reduce: Int }"] <>
  selectedIterable "Checked" "Checked{map: 1, reduce: 2}" "Array[Int]" "[4, 7]"

selectedByteConversion :: [Text]
selectedByteConversion =
  [ "trait Conversion { fn toBytes(self: &Self) -> Str }"
  , "impl Conversion for Option[Str] { fn toBytes(self: &Self) -> Str { \"not bytes\" } }"
  ]

selectedByteArray :: Text -> Text -> [Text]
selectedByteArray element members =
  [ "trait ArrayView { fn toArray(self: &Self) -> Array[" <> element <> "] }"
  , "impl ArrayView for Str { fn toArray(self: &Self) -> Array[" <> element <> "] { " <> members <> " } }"
  , "fn selectedArray(view: dynamic View) -> Array[UInt8] { choose(view).toBytes().toArray() }"
  ]

selectedIntegerPositions :: [Text]
selectedIntegerPositions =
  [ "trait Positions { fn indexOf(self: &Self, label: Str) -> BigInt }"
  , "impl Positions for Option[Str] {"
  , "  fn indexOf(self: &Self, label: Str) -> BigInt {"
  , "    if label == \"large\" { return 18446744073709551616 }"
  , "    if label == \"larger\" { return 18446744073709551617 }"
  , "    if label == \"negative\" { return -18446744073709551617 }"
  , "    2"
  , "  }"
  , "}"
  ]

selectedInvalidPosition :: [Text]
selectedInvalidPosition =
  [ "trait Positions { fn indexOf(self: &Self, label: Str) -> Bool }"
  , "impl Positions for Option[Str] { fn indexOf(self: &Self, label: Str) -> Bool { false } }"
  ]

selectedRangeKey :: [Text]
selectedRangeKey =
  [ "trait HeldRangeKey { fn indexOf(self: &Self, label: Str) -> Range[Int] }"
  , "impl HeldRangeKey for Option[Str] { fn indexOf(self: &Self, label: Str) -> Range[Int] { 1..=2 } }"
  ]

selectedIndexedReceiver :: Text -> Text -> [Text]
selectedIndexedReceiver held body =
  [ "trait CheckedIndexed { fn indexed(self: &Self) -> (Int, Str, Bool) }"
  , "impl CheckedIndexed for Str {"
  , "  fn indexed(self: &Self) -> (Int, Str, Bool) { print(\"indexed\")\n (1, \"tuple\", true) }"
  , "}"
  , "trait HeldIndexed { fn indexed(self: &Self) -> " <> held <> " }"
  , "impl HeldIndexed for Option[Str] {"
  , "  fn indexed(self: &Self) -> " <> held <> " { print(\"indexed\")\n " <> body <> " }"
  , "}"
  ]

selectedSequenceSubject :: [Text]
selectedSequenceSubject =
  [ "trait CheckedParts { fn parts(self: &Self) -> Array[Int] }"
  , "impl CheckedParts for Str { fn parts(self: &Self) -> Array[Int] { [7, 8] } }"
  , "trait HeldParts { fn parts(self: &Self) -> (Int, Int) }"
  , "impl HeldParts for Option[Str] { fn parts(self: &Self) -> (Int, Int) { (7, 8) } }"
  ]

selectedEscapingSubject :: Text -> [Text]
selectedEscapingSubject held =
  [ "trait CheckedItems { fn items(self: &Self) -> Array[Int] }"
  , "impl CheckedItems for Str { fn items(self: &Self) -> Array[Int] { [7, 8] } }"
  , "trait HeldItems { fn items(self: &Self) -> Array[Str] }"
  , "impl HeldItems for Option[Str] { fn items(self: &Self) -> Array[Str] { " <> held <> " } }"
  ]

selectedIntegerTrait :: [Text]
selectedIntegerTrait =
  [ "trait Describe { fn describe(self: &Self) -> Str }"
  , "impl Describe for Int { fn describe(self: &Self) -> Str { \"Int \" + display(*self) } }"
  , "impl Describe for BigInt { fn describe(self: &Self) -> Str { \"BigInt \" + display(*self) } }"
  , "fn box(value: Int) -> dynamic Describe { value }"
  , "fn describe(value: dynamic Describe) -> Str { value.describe() }"
  ]

selectedCollection :: Text -> Text -> [Text]
selectedCollection result body =
  [ "trait CollectionView { fn toArray(self: &Self) -> " <> result <> " }"
  , "impl CollectionView for Str { fn toArray(self: &Self) -> " <> result <> " { " <> body <> " } }"
  , "fn chooseCollection(view: dynamic View) -> Array[UInt8] { choose(view).toBytes().toArray() }"
  ]

selectedPredicate :: [Text]
selectedPredicate =
  [ "trait PredicateView { fn contains(self: &Self, key: Str) -> Str }"
  , "impl PredicateView for Option[Str] {"
  , "  fn contains(self: &Self, key: Str) -> Str { print(\"predicate\")\n \"wrong\" }"
  , "}"
  , "fn checkedPredicate(value: Int) -> Bool { choose(\"λ\".toBytes()).contains(\"x\") }"
  ]

selectedDeclaredCallback :: Text -> Text -> [Text]
selectedDeclaredCallback result callback =
  [ "trait CheckedCallback { fn callback(self: &Self) -> fn(Int) -> Int }"
  , "impl CheckedCallback for Str { fn callback(self: &Self) -> fn(Int) -> Int { increment } }"
  , "trait HeldCallback { fn callback(self: &Self) -> " <> result <> " }"
  , "impl HeldCallback for Option[Str] { fn callback(self: &Self) -> " <> result <> " { " <> callback <> " } }"
  , "fn increment(value: Int) -> Int { value + 1 }"
  ]

checkedLoanMethod :: [Text]
checkedLoanMethod =
  [ "trait CheckedShift { fn shift(self: &Self, value: &mut Int) -> Int }"
  , "impl CheckedShift for Str { fn shift(self: &Self, value: &mut Int) -> Int { *value } }"
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

renderingCallableModulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
renderingCallableModulePrograms =
  [("rendering callable specializations retain canonical nominal owners",
    [("First.pudu", provider "First" "Int"), ("Second.pudu", provider "Second" "Str")], program
      [ "import First as A", "import Second as B"
      , "fn main() -> Int {"
      , "  print(display(A.renderer()(A.Token{value: 7}) == display(A.Token{value: 7})))"
      , "  print(display(B.renderer()(B.Token{value: \"x\"}) == display(B.Token{value: \"x\"})))"
      , "  0", "}" ], "true\ntrue\n")
  , ("same-spelling held patterns require their canonical module owners"
    , [("First.pudu", patternTypes "First"), ("Second.pudu", patternTypes "Second")]
    , program
        ([ "import First as A", "import Second as B" ] <> selectedReceiverTypes <>
          selectedIterable "(A.Token, A.Packet, A.Packet)" "(A.Token{value: 1}, A.Pos(2), A.Fields{value: 3})"
            "(B.Token, B.Packet, B.Packet)" "(B.Token{value: 11}, B.Pos(12), B.Fields{value: 13})" <>
          [ "fn report(view: dynamic View) -> Int {"
          , "  let (record, positional, named) = choose(view).items()"
          , "  if let A.Token{value} = record { print(display(value)) } else { print(\"record miss\") }"
          , "  if let A.Pos(value) = positional { print(display(value)) } else { print(\"positional miss\") }"
          , "  if let A.Fields{value} = named { print(display(value)) } else { print(\"named miss\") }"
          , "  0", "}"
          , "fn main() -> Int {"
          , "  let first = report(\"text\")"
          , "  let second = report(\"λ\".toBytes())"
          , "  first + second", "}"
          ])
    , "receiver\nitems\n1\n2\n3\nreceiver\nitems\nrecord miss\npositional miss\nnamed miss\n")
  ]
 where
  provider name field = Text.unlines
    [ "module " <> name, "export type Token = { value: " <> field <> " }"
    , "export fn renderer() -> fn(Token) -> Str { display }" ]
  patternTypes name = Text.unlines
    [ "module " <> name, "export type Token = { value: Int }"
    , "export type Packet = Pos(Int) | Fields{value: Int}" ]
