{-| @Test.Backend.GenericPrograms — generic functions, implementations and
    records, one copy per type-argument list. -}
module Pudu.Backend.GenericPrograms (genericSuccessPrograms, genericRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

genericSuccessPrograms :: [(String, Text, Text)]
genericSuccessPrograms =
  [ ("one generic function runs at several types", program
      [ "fn identity[T](value: T) -> T { value }"
      , "fn pair[A, B](left: A, right: B) -> (A, B) { (identity(left), right) }"
      , "fn main() -> Int {"
      , "  print(display(identity(3)))", "  print(identity(\"text\"))", "  print(display(identity(2.5)))"
      , "  print(show(pair(1, \"a\")))", "  print(show(pair(pair(true, 'c'), ())))"
      , "  return 0", "}" ]
    , "3\ntext\n2.5\n(1, \"a\")\n((true, 'c'), ())\n")
  , ("generic records build, read, update, compare and render", program
      [ "type Box[T] = { value: T, label: Str }"
      , "fn wrap[T](value: T) -> Box[T] { Box{value: value, label: \"box\"} }"
      , "fn main() -> Int {"
      , "  let number = wrap(4)", "  let text = wrap(\"s\")"
      , "  print(show(number) + \" \" + show(text))"
      , "  print(display(number.value + 1) + text.value)"
      , "  let changed = Box{..number, value: 9}"
      , "  print(display(changed == number) + \" \" + display(changed == Box{value: 9, label: \"box\"}))"
      , "  match changed { case Box{value, label} => print(label + \" holds \" + display(value)) }"
      , "  return 0", "}" ]
    , "Box{value: 4, label: \"box\"} Box{value: \"s\", label: \"box\"}\n5s\nfalse true\nbox holds 9\n")
  , ("bounded calls and generic implementations with their defaults", program
      [ "trait Named {"
      , "  fn name(self: &Self) -> Str"
      , "  fn loud(self: &Self) -> Str { self.name() + \"!\" }"
      , "}"
      , "type Box[T] = { value: T }", "type Point = { x: Int }"
      , "impl Named for Point { fn name(self: &Self) -> Str { \"point \" + display(self.x) } }"
      , "impl[T] Named for Box[T] { fn name(self: &Self) -> Str { \"box\" } }"
      , "fn describe[T: Named](value: T) -> Str { value.name() + \" / \" + value.loud() }"
      , "fn twice[T: Named](value: T) -> Str { describe(value) + \" | \" + describe(value) }"
      , "fn main() -> Int {"
      , "  print(describe(Point{x: 7}))", "  print(describe(Box{value: 1}))"
      , "  print(Box{value: \"s\"}.loud())", "  print(twice(Box{value: Point{x: 1}}))"
      , "  return 0", "}" ]
    , "point 7 / point 7!\nbox / box!\nbox!\nbox / box! | box / box!\n")
  , ("generic sums recurse and match", program
      [ "type List[T] = Empty | Cell(T, List[T])"
      , "fn length[T](list: List[T]) -> Int {"
      , "  match list { case Empty => 0 case Cell(_, rest) => 1 + length(rest) }", "}"
      , "fn firstOr[T](items: Option[T], fallback: T) -> T {"
      , "  match items { case Some(found) => found case None => fallback }", "}"
      , "fn main() -> Int {"
      , "  let numbers = Cell(1, Cell(2, Cell(3, Empty)))"
      , "  let words = Cell(\"a\", Empty)"
      , "  print(display(length(numbers)) + \" \" + display(length(words)))"
      , "  print(display(firstOr(Some(4), 0)) + \" \" + firstOr(None, \"none\"))"
      , "  print(show(numbers))"
      , "  return 0", "}" ]
    , "3 1\n4 none\nCell(1, Cell(2, Cell(3, Empty)))\n")
  ]

{-| Failures inside a copy report at the generic body's own source. -}
genericRefusalPrograms :: [(String, Text)]
genericRefusalPrograms =
  [ ("an overflow inside a specialized body keeps its span", program
      [ "fn apply[T](value: T, by: Int) -> (T, Int) { (value, by + 9223372036854775807) }"
      , "fn main() -> Int {", "  print(show(apply(\"x\", 0)))"
      , "  print(show(apply(true, 1)))", "  return 0", "}" ])
  , ("a bounded default fails at the trait's source", program
      [ "trait Ratio {"
      , "  fn top(self: &Self) -> Int"
      , "  fn over(self: &Self, by: Int) -> Int { self.top() / by }"
      , "}"
      , "type Holder[T] = { held: T, top: Int }"
      , "impl[T] Ratio for Holder[T] { fn top(self: &Self) -> Int { self.top } }"
      , "fn split[R: Ratio](value: R, by: Int) -> Int { value.over(by) }"
      , "fn main() -> Int {", "  print(display(split(Holder{held: \"a\", top: 10}, 5)))"
      , "  print(display(split(Holder{held: 'b', top: 10}, 0)))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
