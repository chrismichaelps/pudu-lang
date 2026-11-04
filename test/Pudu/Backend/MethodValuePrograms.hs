{-| @Test.Backend.MethodValuePrograms — built-in methods taken as values keep
    their receiver, render, compare and fail as the interpreter's do. -}
module Pudu.Backend.MethodValuePrograms
  ( methodValueSuccessPrograms, methodValueRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text

methodValueSuccessPrograms :: [(String, Text, Text, Text)]
methodValueSuccessPrograms =
  [ ("text, array and map methods are values bound to their receivers", program
      [ "fn main() -> Int {"
      , "  let text = \"hello\""
      , "  let size = text.length"
      , "  print(display(size()))"
      , "  let upper = text.toUpper"
      , "  print(upper())"
      , "  let items = [1, 2]"
      , "  let add = items.push"
      , "  print(show(add(3)))"
      , "  print(show(size))"
      , "  print(show(add))"
      , "  let m = mapOf([(\"a\", 1)])"
      , "  let get = m.get"
      , "  print(show(get(\"a\")))"
      , "  0"
      , "}" ]
    , "5\nHELLO\n[1, 2, 3]\n<text method length>\n<array method push>\nSome(1)\n", "")
  , ("method values of every receiver kind render, compare and survive records and generics", program
      [ "type Tools = { size: fn() -> Int, upper: fn() -> Str }"
      , "fn apply[T](f: fn() -> T) -> T { f() }"
      , "fn main() -> Int {"
      , "  var text = \"hello\""
      , "  let size = text.length"
      , "  text = \"changed\""
      , "  print(display(size()))"
      , "  let tools = Tools{size: \"abc\".length, upper: \"abc\".toUpper}"
      , "  print(display(tools.size()) + tools.upper())"
      , "  print(display(apply(\"xy\".length)))"
      , "  print(show(tools))"
      , "  print(display(\"a\".length == \"b\".length))"
      , "  let bytes = bytesOf([1u8, 2u8])"
      , "  print(show(bytes.length))"
      , "  print(display((bytes.length)()))"
      , "  let range = 1..4"
      , "  let has = range.contains"
      , "  print(display(has(3)) + \" \" + display(has(9)))"
      , "  let keyed = mapOf([(\"a\", 1)])"
      , "  let has_key = keyed.containsKey"
      , "  print(display(has_key(\"a\")))"
      , "  let members = setOf([1, 2])"
      , "  let grow = members.insert"
      , "  print(show(grow(5)))"
      , "  print(show('z'.code))"
      , "  var total = 0"
      , "  for index in 0..200 {"
      , "    let joined = [\"x\".repeat(index), \"y\"].join"
      , "    total = total + joined(\",\").length()"
      , "  }"
      , "  print(display(total))"
      , "  0"
      , "}" ]
    , "5\n3ABC\n2\nTools{size: <text method length>, upper: <text method toUpper>}\nfalse\n<byte method length>\n2\ntrue false\ntrue\n#{1, 2, 5}\n<character method code>\n20300\n", "")
  , ("method values answer Options, arrays and slices as their calls do", program
      [ "fn main() -> Int {"
      , "  let items = [1, 2, 3]"
      , "  let pick = items.get"
      , "  print(show(pick(1)))"
      , "  let numbers = \"1,2,x\".split"
      , "  print(show(numbers(\",\")))"
      , "  let parse = \"12a\".toInt"
      , "  print(show(parse()))"
      , "  let slice = \"hello\".slice"
      , "  print(slice(1, 99))"
      , "  0"
      , "}" ]
    , "2\n[\"1\", \"2\", \"x\"]\nNone\nello\n", "")
  , ("trait methods are values bound to records or named through their type", program
      [ "trait Named {"
      , "  fn label(self, suffix: Str) -> Str"
      , "}"
      , "type Bot = { name: Str }"
      , "impl Named for Bot {"
      , "  fn label(self: Bot, suffix: Str) -> Str { self.name + suffix }"
      , "}"
      , "fn main() -> Int {"
      , "  let bot = Bot{name: \"r2\"}"
      , "  let tag = bot.label"
      , "  print(tag(\"!\"))"
      , "  print(show(tag))"
      , "  print(display(tag == bot.label))"
      , "  print(display(tag == Bot{name: \"c3\"}.label))"
      , "  let direct = Bot.label"
      , "  print(direct(bot, \"?\"))"
      , "  0"
      , "}" ]
    , "r2!\n<fn label>\ntrue\nfalse\nr2?\n", "")
  , ("trait methods of sums are values in arrays and records with receiver equality", program
      [ "trait Area {"
      , "  fn area(self) -> Int"
      , "}"
      , "type Shape = Square(Int) | Rect(Int, Int)"
      , "impl Area for Shape {"
      , "  fn area(self: Shape) -> Int {"
      , "    match self {"
      , "      case Square(side) => side * side"
      , "      case Rect(w, h) => w * h"
      , "    }"
      , "  }"
      , "}"
      , "type Holder = { run: fn() -> Int }"
      , "fn make(label: Str) -> Shape { print(\"making \" + label)"
      , " Rect(2, 3) }"
      , "fn main() -> Int {"
      , "  let measure = make(\"a\").area"
      , "  print(\"bound\")"
      , "  print(display(measure()))"
      , "  let fns = [Square(3).area, Rect(1, 5).area]"
      , "  for f in fns { print(display(f())) }"
      , "  print(display(Square(2).area == Square(2).area))"
      , "  print(display(Square(2).area == Square(3).area))"
      , "  let holder = Holder{run: Square(4).area}"
      , "  let run = holder.run"
      , "  print(display(run()))"
      , "  print(show(holder))"
      , "  0"
      , "}" ]
    , "making a\nbound\n6\n9\n5\ntrue\nfalse\n16\nHolder{run: <fn area>}\n", "")
  ]

methodValueRefusalPrograms :: [(String, Text)]
methodValueRefusalPrograms =
  [ ("a method value fails at the call made through it", program
      [ "fn source() -> Str { print(\"receiver\")"
      , " \"abc\" }"
      , "fn main() -> Int {"
      , "  let size = source().length"
      , "  print(\"bound\")"
      , "  print(display(size()))"
      , "  let t = \"x\""
      , "  print(display(t.length == t.length))"
      , "  print(display(t.length == \"y\".length))"
      , "  let items = [1, 2, 3]"
      , "  let at = items.get"
      , "  print(show(at(1)))"
      , "  print(show('a'.code))"
      , "  print(show((0..3).contains))"
      , "  let s = setOf([1])"
      , "  print(show(s.contains))"
      , "  let pick = \"abc\".charAt"
      , "  print(show(pick(9)))"
      , "  0"
      , "}" ])
  , ("a key refusal inside a method value names the call through it", program
      [ "fn inc(x: Int) -> Int { x + 1 }"
      , "fn main() -> Int {"
      , "  let members: Set[fn(Int) -> Int] = setOf([])"
      , "  let grow = members.insert"
      , "  print(\"before\")"
      , "  print(show(grow(inc).size()))"
      , "  0"
      , "}" ])
  , ("a failure inside a trait method value keeps the method body's span", program
      [ "trait Divide {"
      , "  fn split(self, parts: Int) -> Int"
      , "}"
      , "type Pile = { size: Int }"
      , "impl Divide for Pile {"
      , "  fn split(self: Pile, parts: Int) -> Int { self.size / parts }"
      , "}"
      , "fn main() -> Int {"
      , "  let split = Pile{size: 10}.split"
      , "  print(display(split(2)))"
      , "  print(display(split(0)))"
      , "  0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
