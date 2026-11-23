{-| @Test.Backend.RenderingCallablePrograms — rendering values keep builtin semantics. -}
module Pudu.Backend.RenderingCallablePrograms
  ( renderingCallableSuccessPrograms, renderingCallableRefusalPrograms, renderingCallableModulePrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

renderingCallableSuccessPrograms :: [(String, Text, Text, Text)]
renderingCallableSuccessPrograms =
  [
    ("rendering builtin signatures and identities coexist", program
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
    ("rendering builtin unary failures name builtin", program
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
      , "  0", "}" ], "true\ntrue\n")]
 where
  provider name field = Text.unlines
    [ "module " <> name, "export type Token = { value: " <> field <> " }"
    , "export fn renderer() -> fn(Token) -> Str { display }" ]
