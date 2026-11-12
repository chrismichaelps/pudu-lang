{-| @Test.Backend.TextViewPrograms — byte offsets, UTF-8 boundaries and shared owners. -}
module Pudu.Backend.TextViewPrograms (textViewSuccessPrograms, textViewRefusalPrograms, textViewFacadePrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

textViewSuccessPrograms :: [(String, Text, Text)]
textViewSuccessPrograms =
  [ ("text-view byte and scalar carriers at every mixed-width offset", deferredProgram
      [ "fn main() -> Int {"
      , "  let text = \"aé中😀z\""
      , "  var units: Array[Option[UInt8]] = []"
      , "  var scalars: Array[Option[(Char, Int)]] = []"
      , "  for at in [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 9223372036854775807, deferred] {"
      , "    units = units.push(textByteAt(text, at))"
      , "    scalars = scalars.push(textScalarAt(text, at))"
      , "  }"
      , "  print(show(textByteSize(text)) + \" \" + show(textByteSize(\"\")))"
      , "  print(show(units))\n print(show(scalars))"
      , "  if let Some(byte) = textByteAt(\"😀\", 0) { print(show(byte &+ 16u8)) }"
      , "  0", "}" ]
    , "11 0\n[None, Some(97), Some(195), Some(169), Some(228), Some(184), Some(173), Some(240), Some(159), Some(152), Some(128), Some(122), None, None, None, None]\n[None, Some(('a', 1)), Some(('é', 2)), None, Some(('中', 3)), None, None, Some(('😀', 4)), None, None, None, Some(('z', 1)), None, None, None, None]\n0\n")
  , ("text-view slices admit only ordered scalar boundaries", deferredProgram
      [ "fn far(at: Int) -> Option[Str] { textByteSlice(\"abc\", at, at) }"
      , "fn boundary(at: Int) -> Bool { at == 0 || at == 1 || at == 3 || at == 6 || at == 10 || at == 11 }"
      , "fn main() -> Int { let text = \"aé中😀z\"\n var checked = 0"
      , "  for start in -1..13 { for end in -1..13 {"
      , "    let sliced = textByteSlice(text, start, end)"
      , "    if (sliced != None) != (start <= end && boundary(start) && boundary(end)) { panic(\"slice boundary\") }"
      , "    if let Some(value) = sliced { if textByteSize(value) != end - start { panic(\"slice length\") } }"
      , "    checked = checked + 1"
      , "  } }"
      , "  print(show(checked))"
      , "  print(show(textByteSlice(text, 1, 6)) + \" \" + show(textByteSlice(text, 6, 10)))"
      , "  print(show(textByteSlice(text, 11, 11)) + \" \" + show(textByteSlice(\"\", 0, 0)))"
      , "  print(show(textByteSlice(text, 0, 9223372036854775807)) + show(far(deferred)) + show(textByteSlice(text, minimum, 0)))"
      , "  0", "}" ]
    , "196\nSome(\"é中\") Some(\"😀\")\nSome(\"\") Some(\"\")\nNoneNoneNone\n")
  , ("text-view searches retain byte positions and overlapping last matches", deferredProgram
      [ "fn far(at: Int) -> Option[Int] { textByteFind(\"abc\", \"\", at) }"
      , "fn main() -> Int { let text = \"aééz\""
      , "  print(show(textByteFind(text, \"é\", 0)) + show(textByteFind(text, \"é\", 2)) + show(textByteFind(text, \"é\", 4)))"
      , "  print(show(textByteFind(text, \"\", 2)) + show(textByteFind(text, \"\", 6)) + show(textByteFind(text, \"\", 7)))"
      , "  print(show(textByteFind(text, \"é\", -1)) + show(far(deferred)))"
      , "  print(show(textByteFindLast(\"aaaa\", \"aa\")) + show(textByteFindLast(\"aaa\", \"aa\")) + show(textByteFindLast(text, \"é\")))"
      , "  print(show(textByteFindLast(\"\", \"\")) + show(textByteFindLast(text, \"\")) + show(textByteFindLast(\"a\", \"aa\")) + show(textByteFindLast(\"abc\", \"x\")))"
      , "  0", "}" ]
    , "Some(1)Some(3)None\nSome(2)Some(6)None\nNoneNone\nSome(2)Some(1)Some(3)\nSome(0)Some(6)NoneNone\n")
  , ("text-view slices survive sources and decode embedded NUL", program
      [ "fn made() -> Option[Str] { var text = \"\"\n for piece in [\"left\", \"é中😀\", \"right\"] { text = text + piece }\n textByteSlice(text, 4, 13) }"
      , "fn nested() -> Option[Str] { let parent = made() ?\n textByteSlice(parent, 2, 5) }"
      , "fn main() -> Int { print(show(nested()))"
      , "  if let Some(zero) = charFromCode(0) { let text = \"a\" + zero.toText() + \"b\""
      , "    print(show(textByteSize(text)) + \" \" + show(textByteAt(text, 1)) + \" \" + show(textByteFind(text, zero.toText(), 0)) + \" \" + show(textByteFindLast(text, zero.toText())))"
      , "    if let Some((scalar, width)) = textScalarAt(text, 1) { print(show(scalar.code()) + \" \" + show(width)) }"
      , "    if let Some(view) = textByteSlice(text, 1, 2) { print(show(textByteAt(view, 0) == Some(0u8))) }"
      , "  }\n 0", "}" ]
    , "Some(\"中\")\n3 Some(0) Some(1) Some(1)\n0 1\ntrue\n")
  -- Current computed-callee order is tracked for normative repair in #828.
  , ("text-view callable identities and builtin argument snapshots", program
      [ "fn capture(f: fn(Str, Int) -> Option[UInt8]) { |text, at| f(text, at) }"
      , "fn make() -> fn(Str, Int) -> Option[UInt8] { print(\"callee\")\n textByteAt }"
      , "fn main() -> Int { let at = textByteAt\n let size = textByteSize\n let slice = textByteSlice\n let find = textByteFind\n let last = textByteFindLast\n let scalar = textScalarAt"
      , "  print(show(at) + \" \" + show(at == textByteAt))"
      , "  print(show(capture(at)(\"é\", 1)) + \" \" + show(size(\"é\")) + \" \" + show(slice(\"é\", 0, 2)))"
      , "  print(show(find(\"éé\", \"é\", 1)) + \" \" + show(last(\"aaa\", \"aa\")) + \" \" + show(scalar(\"é\", 0)))"
      , "  var held = \"a\"\n print(show(textByteAt(held, { held = \"b\"\n 0 })))"
      , "  var source = \"needle\"\n print(show(textByteFind(source, { source = \"other\"\n \"needle\" }, 0)))"
      , "  held = \"a\"\n print(show(make()({ print(\"text\")\n held }, { print(\"index\")\n held = \"b\"\n 0 })))"
      , "  0", "}" ]
    , "<builtin textByteAt> true\nSome(169) 2 Some(\"é\")\nSome(2) Some(1) Some(('é', 2))\nSome(97)\nSome(0)\ntext\nindex\ncallee\nSome(97)\n")
  , ("text-view first operand transfer skips later work", program
      [ "fn later() -> Int { print(\"unreachable\")\n 0 }"
      , "fn main() -> Int { textByteSlice({ print(\"transfer\")\n return 0 }, later(), later())\n 1 }" ], "transfer\n")
  , ("text-view middle operand transfer retains earlier effects", program
      [ "fn later() -> Int { print(\"unreachable\")\n 0 }"
      , "fn main() -> Int { textByteFind({ print(\"text\")\n \"x\" }, { print(\"transfer\")\n return 0 }, later())\n 1 }" ], "text\ntransfer\n")
  , ("a source function keeps a text-view builtin spelling", program
      [ "fn textByteSize(value: Int) -> Int { value + 4 }"
      , "fn main() -> Int { let f = textByteSize\n print(show(f(1)))\n 0 }" ], "5\n")
  ]

textViewRefusalPrograms :: [(String, Text)]
textViewRefusalPrograms =
  [ ("text-view UInt8 payload keeps checked arithmetic", program
      [ "fn main() -> Int { if let Some(byte) = textByteAt(\"😀\", 0) { print(show(byte + 16u8)) }\n 0 }" ])
  , ("text-view direct argument failure skips later effects", program
      [ "fn later() -> Int { print(\"unreachable\")\n 0 }"
      , "fn main() -> Int { let n = 0\n textByteSlice({ print(\"failure\")\n let bad = 1 / n\n \"text\" }, later(), later())\n 0 }" ])
  , ("text-view value argument failure retains call provenance", program
      [ "fn main() -> Int { let find = textByteFind\n let n = 0"
      , "  print(show(find({ print(\"text\")\n \"text\" }, { print(\"failure\")\n let bad = 1 / n\n \"x\" }, 0)))\n 0 }" ])
  ] <> [("text-view builtin entry " <> Text.unpack name, program ["fn main() -> " <> signature <> " { " <> name <> " }"])
       | (name, signature) <-
          [("textByteSize", "fn(Str) -> Int"), ("textByteAt", "fn(Str, Int) -> Option[UInt8]")
          ,("textByteSlice", "fn(Str, Int, Int) -> Option[Str]"), ("textByteFind", "fn(Str, Str, Int) -> Option[Int]")
          ,("textByteFindLast", "fn(Str, Str) -> Option[Int]"), ("textScalarAt", "fn(Str, Int) -> Option[(Char, Int)]")]]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)


{-| Settle the deferred magnitude before it enters a context requiring Int. -}
deferredProgram :: [Text] -> Text
deferredProgram = program . map (Text.replace "fn main() -> Int {"
  "fn main() -> Int {\n  let deferred = 9223372036854775808\n  let minimum: Int = -deferred\n")


textViewFacadePrograms :: [(String, Text, Text)]
textViewFacadePrograms = [("text-view public StringView integration", Text.unlines
  [ "module Main", "import Std.StringView as StringView", "import Std.StringView {View}", "import Std.Iter {Sequence}"
  , "fn main() -> Int { let view = StringView.of(\"aéz\")"
  , "  print(show(view.size()) + \" \" + show(view.byteAt(2)))"
  , "  print(show(view.byteUnits().toArray()))"
  , "  if let Some(piece) = view.substr(1, 2) { print(piece.toText()) }"
  , "  var target = [0u8, 0u8, 255u8]"
  , "  print(show(view.copyInto(&mut target, 2, 1)) + show(target))"
  , "  print(show(view.findLastFrom(\"é\", 2)) + \" \" + show(view.findLastOf(\"é\", 99)))"
  , "  0", "}" ], "4 Some(169)\n[97, 195, 169, 122]\né\nSome(2)[195, 169, 255]\nSome(1) Some(2)\n")]
