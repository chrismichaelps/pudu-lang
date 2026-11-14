{-| @Test.Backend.CollectionCallablePrograms — charFromCode, bytesOf, mapOf
    and setOf as values answer and refuse exactly as their direct calls. -}
module Pudu.Backend.CollectionCallablePrograms
  ( collectionCallableSuccessPrograms, collectionCallableRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text

collectionCallableSuccessPrograms :: [(String, Text, Text, Text)]
collectionCallableSuccessPrograms =
  [ ("collection builtins called through values answer as direct calls", program
      [ "fn main() -> Int {"
      , "  let c: fn(Int) -> Option[Char] = charFromCode"
      , "  let b: fn(Array[UInt8]) -> Bytes = bytesOf"
      , "  let m: fn(Array[(Str, Int)]) -> Map[Str, Int] = mapOf"
      , "  let s: fn(Array[Int]) -> Set[Int] = setOf"
      , "  print(show(c(65)))"
      , "  print(show(c(55296)))"
      , "  print(show(b([1, 2, 255])))"
      , "  print(show(m([(\"a\", 1), (\"b\", 2), (\"a\", 3)])))"
      , "  print(show(s([3, 1, 3])))"
      , "  print(show(c))"
      , "  print(display(b))"
      , "  print(display(c == charFromCode))"
      , "  print(display(m == mapOf))"
      , "  print(show(b([255u8])))"
      , "  0"
      , "}" ]
    , "Some('A')\nNone\n0x0102ff\n{\"a\": 3, \"b\": 2}\n#{1, 3}\n<builtin charFromCode>\n<builtin bytesOf>\ntrue\ntrue\n0xff\n", "")
  , ("unconstrained builtin values compare and render", program
      [ "fn main() -> Int {"
      , "  print(display(display == show))"
      , "  print(display(show == show))"
      , "  print(show(setOf))"
      , "  print(display(setOf == setOf))"
      , "  print(show(setOf([])))"
      , "  print(show(mapOf([]).size()))"
      , "  let f = setOf"
      , "  print(show(f([2, 1])))"
      , "  let none = None"
      , "  print(show([none, None]))"
      , "  print(display(charFromCode == charFromCode))"
      , "  print(show(bytesOf([])))"
      , "  0"
      , "}" ]
    , "false\ntrue\n<builtin setOf>\ntrue\n#{}\n0\n#{1, 2}\n[None, None]\ntrue\n0x\n", "")
  , ("collection builtin signatures coexist and keep one identity", program
      [ "fn build[T](items: Array[T], make: fn(Array[T]) -> Set[T]) -> Set[T] { make(items) }"
      , "fn main() -> Int {"
      , "  let byText: fn(Array[(Str, Int)]) -> Map[Str, Int] = mapOf"
      , "  let byNumber: fn(Array[(Int, Bool)]) -> Map[Int, Bool] = mapOf"
      , "  print(show(byText([(\"b\", 2), (\"a\", 1)])))"
      , "  print(show(byNumber([(2, true), (1, false), (2, false)])))"
      , "  print(show(build([3, 1, 2], setOf)))"
      , "  print(show(build([\"z\", \"y\", \"z\"], setOf)))"
      , "  print(show(build([(1, \"a\"), (0, \"b\")], setOf)))"
      , "  print(display(setOf == setOf))"
      , "  print(show(byText == mapOf))"
      , "  0"
      , "}" ]
    , "{\"a\": 1, \"b\": 2}\n{1: false, 2: false}\n#{1, 2, 3}\n#{\"y\", \"z\"}\n#{(0, \"b\"), (1, \"a\")}\ntrue\ntrue\n", "")
  , ("collection values survive records captures returns and arrays", program
      [ "type Maker = { make: fn(Array[UInt8]) -> Bytes }"
      , "fn chooser() -> fn(Array[Int]) -> Set[Int] { setOf }"
      , "fn decoder(convert: fn(Int) -> Option[Char]) -> fn(Int) -> Str {"
      , "  |code| if let Some(c) = convert(code) { display(c) } else { \"?\" }"
      , "}"
      , "fn main() -> Int {"
      , "  let holder = Maker{make: bytesOf}"
      , "  print(show(holder.make({ print(\"argument\")"
      , " [104u8, 105u8] })))"
      , "  print(show(chooser()([2, 2, 1])))"
      , "  let decode = decoder(charFromCode)"
      , "  print(decode(97) + decode(-1) + decode(0x1F600))"
      , "  let makers: Array[fn(Array[UInt8]) -> Bytes] = [bytesOf, |items| bytesOf(items.push(0u8))]"
      , "  for make in makers { print(show(make([7u8]))) }"
      , "  print(show(holder))"
      , "  0"
      , "}" ]
    , "argument\n0x6869\n#{1, 2}\na?😀\n0x07\n0x0700\nMaker{make: <builtin bytesOf>}\n", "")
  , ("charFromCode values test every scalar boundary", program
      [ "fn main() -> Int {"
      , "  let decode: fn(Int) -> Option[Char] = charFromCode"
      , "  for code in [-1, 0, 0xD7FF, 0xD800, 0xDFFF, 0xE000, 0x10FFFF, 0x110000] {"
      , "    if let Some(c) = decode(code) { print(\"some\") } else { print(\"none\") }"
      , "  }"
      , "  print(show(decode(65)))"
      , "  0"
      , "}" ]
    , "none\nsome\nsome\nnone\nnone\nsome\nsome\nnone\nSome('A')\n", "")
  , ("nearer source and local collection declarations win", program
      [ "fn mapOf(items: Array[(Str, Int)]) -> Int { items.length() }"
      , "fn main() -> Int {"
      , "  let counted = mapOf"
      , "  print(show(counted([(\"a\", 1)])))"
      , "  print(show(counted))"
      , "  let setOf: fn(Array[Int]) -> Int = |items| items.length() * 10"
      , "  print(show(setOf([1, 2])))"
      , "  let real: fn(Array[Int]) -> Bytes = |items| bytesOf([])"
      , "  print(show(charFromCode))"
      , "  0"
      , "}" ]
    , "1\n<fn mapOf>\n20\n<builtin charFromCode>\n", "")
  , ("collection builtin entry reports its tag", program
      [ "fn main() -> fn(Int) -> Option[Char] { charFromCode }" ]
    , "<builtin charFromCode>\n", "")
  , ("keys that could hold functions pass when every key orders", program
      [ "fn main() -> Int {"
      , "  let keyed: fn(Array[(Option[fn(Int) -> Int], Str)]) -> Map[Option[fn(Int) -> Int], Str] = mapOf"
      , "  print(show(keyed([(None, \"a\"), (None, \"b\")]).size()))"
      , "  let members: fn(Array[Str]) -> Set[Str] = setOf"
      , "  var total = 0"
      , "  for index in 0..200 { total = total + members([\"x\".repeat(64), \"y\".repeat(index)]).size() }"
      , "  print(show(total))"
      , "  0"
      , "}" ]
    , "1\n400\n", "")
  ]

-- Each refusal must point at the call made through the value, not at the
-- place the builtin was named.
collectionCallableRefusalPrograms :: [(String, Text)]
collectionCallableRefusalPrograms =
  [ ("set member refusal through a value names the call", program
      [ "fn inc(x: Int) -> Int { x + 1 }"
      , "fn main() -> Int {"
      , "  let build: fn(Array[fn(Int) -> Int]) -> Set[fn(Int) -> Int] = setOf"
      , "  print(\"before\")"
      , "  let s = build([inc])"
      , "  print(display(s.size()))"
      , "  0"
      , "}" ])
  , ("refusal through a record field names the field call", program
      [ "type Maker = { make: fn(Array[Option[fn(Int) -> Int]]) -> Set[Option[fn(Int) -> Int]] }"
      , "fn inc(x: Int) -> Int { x + 1 }"
      , "fn main() -> Int {"
      , "  let holder = Maker{make: setOf}"
      , "  print(show(holder.make([None, None]).size()))"
      , "  print(show(holder.make([None, Some(inc)]).size()))"
      , "  0"
      , "}" ])
  , ("refusal through a generic caller names the call inside it", program
      [ "fn inc(x: Int) -> Int { x + 1 }"
      , "fn build[T](items: Array[T], make: fn(Array[(T, Int)]) -> Map[T, Int]) -> Int {"
      , "  var pairs: Array[(T, Int)] = []"
      , "  for item in items { pairs = pairs.push((item, 1)) }"
      , "  make(pairs).size()"
      , "}"
      , "fn main() -> Int {"
      , "  print(show(build([1, 2], mapOf)))"
      , "  print(show(build([inc], mapOf)))"
      , "  0"
      , "}" ])
  , ("nested value calls name the inner call", program
      [ "fn inc(x: Int) -> Int { x + 1 }"
      , "fn main() -> Int {"
      , "  let outer: fn(Array[Int]) -> Set[Int] = setOf"
      , "  let inner: fn(Array[fn(Int) -> Int]) -> Set[fn(Int) -> Int] = setOf"
      , "  print(show(outer([inner([inc]).size()])))"
      , "  0"
      , "}" ])
  , ("collection value arguments fail before dispatch", program
      [ "fn main() -> Int {"
      , "  let decode: fn(Int) -> Option[Char] = charFromCode"
      , "  print(show(decode({ print(\"argument\")"
      , " 1 / 0 })))"
      , "  0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
