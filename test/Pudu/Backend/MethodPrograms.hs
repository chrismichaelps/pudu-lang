{-| @Test.Backend.MethodPrograms — implementation members, trait defaults,
    qualified selection and evaluation order. -}
module Pudu.Backend.MethodPrograms (methodSuccessPrograms, methodRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

named :: [Text]
named =
  [ "trait Named {"
  , "  fn name(self: &Self) -> Str"
  , "  fn greet(self: &Self, other: Str) -> Str { \"hi \" + other + \" from \" + self.name() }"
  , "}"
  , "type Point = { x: Int, y: Int }"
  , "type Shape = Circle(Int) | Square(Int)"
  , "impl Named for Point {"
  , "  fn name(self: &Self) -> Str { \"point \" + display(self.x) }"
  , "}"
  , "impl Named for Shape {"
  , "  fn name(self: &Self) -> Str {"
  , "    match self { case Circle(r) => \"circle \" + display(r) case Square(s) => \"square \" + display(s) }"
  , "  }"
  , "  fn greet(self: &Self, other: Str) -> Str { \"shape greets \" + other }"
  , "}"
  ]

methodSuccessPrograms :: [(String, Text, Text)]
methodSuccessPrograms =
  [ ("implementation members and inherited defaults on records and sums", program $ named <>
      [ "fn main() -> Int {"
      , "  let p = Point{x: 1, y: 2}", "  let s = Circle(3)"
      , "  print(p.name())", "  print(p.greet(\"you\"))"
      , "  print(s.name())", "  print(s.greet(\"x\"))", "  print(Square(2).greet(\"y\"))"
      , "  return 0", "}" ]
    , "point 1\nhi you from point 1\ncircle 3\nshape greets x\nshape greets y\n")
  , ("qualified calls select by type and by trait", program $ named <>
      [ "trait Origin { fn origin() -> Self }"
      , "impl Origin for Point { fn origin() -> Point { Point{x: 0, y: 0} } }"
      , "fn main() -> Int {"
      , "  let p = Point{x: 5, y: 6}"
      , "  print(Point.name(&p))", "  print(Named.name(&p))", "  print(Named.greet(&Square(4), \"q\"))"
      , "  print(Point.origin().name())", "  print(show(Point.origin()))"
      , "  return 0", "}" ]
    , "point 5\npoint 5\nshape greets q\npoint 0\nPoint{x: 0, y: 0}\n")
  , ("arguments run before the receiver and may change it", program $ named <>
      [ "fn tag(label: Str) -> Str {", "  print(label)", "  label", "}"
      , "fn make(x: Int) -> Point {", "  print(\"receiver\")", "  Point{x: x, y: 0}", "}"
      , "fn main() -> Int {"
      , "  print(make(4).greet(tag(\"arg\")))"
      , "  var p = Point{x: 1, y: 1}"
      , "  print(p.greet({ p = Point{x: 9, y: 9}", "    \"z\" }))"
      , "  return 0", "}" ]
    , "arg\nreceiver\nhi arg from point 4\nhi z from point 9\n")
  , ("an argument that returns stops the call before the receiver", program $ named <>
      [ "fn make() -> Point {", "  print(\"never\")", "  Point{x: 0, y: 0}", "}"
      , "fn early() -> Str {", "  make().greet({ return \"early\" })", "}"
      , "fn main() -> Int {", "  print(early())", "  return 0", "}" ]
    , "early\n")
  , ("builtin types take implementations and every value answers toText", program
      [ "trait Describe { fn describe(self: &Self) -> Str }"
      , "impl Describe for Int { fn describe(self: &Self) -> Str { \"int \" + display(*self) } }"
      , "impl Describe for Str { fn describe(self: &Self) -> Str { \"text \" + *self } }"
      , "type Pair = { left: Int, right: Bool }"
      , "type Light = Red | Green"
      , "fn main() -> Int {"
      , "  let count = 42"
      , "  print(count.describe())", "  print(\"pudu\".describe() + \" \" + display(\"pudu\".length()))"
      , "  print(count.toText() + \" \" + true.toText() + \" \" + (1, \"a\").toText())"
      , "  print(Pair{left: 1, right: false}.toText() + \" \" + Green.toText() + \" \" + \"s\".toText())"
      , "  print(2.5.toText() + \" \" + 'c'.toText())"
      , "  return 0", "}" ]
    , "int 42\ntext pudu 4\n42 true (1, \"a\")\nPair{left: 1, right: false} Green s\n2.5 c\n")
  , ("a type's own toText wins over the universal one", program
      [ "trait Render { fn toText(self: &Self) -> Str }"
      , "type Money = { cents: Int }"
      , "impl Render for Money { fn toText(self: &Self) -> Str { \"$\" + display(self.cents / 100) } }"
      , "fn main() -> Int {", "  print(Money{cents: 1250}.toText())", "  return 0", "}" ]
    , "$12\n")
  , ("methods recurse, return Self and call each other", program
      [ "trait Count {"
      , "  fn down(self: &Self, n: Int) -> Int"
      , "  fn twice(self: &Self) -> Self"
      , "  fn total(self: &Self) -> Int { self.down(3) + self.twice().down(0) }"
      , "}"
      , "type Step = { size: Int }"
      , "impl Count for Step {"
      , "  fn down(self: &Self, n: Int) -> Int { if n == 0 { self.size } else { self.size + self.down(n - 1) } }"
      , "  fn twice(self: &Self) -> Step { Step{size: self.size * 2} }"
      , "}"
      , "fn main() -> Int {", "  let step = Step{size: 5}"
      , "  print(display(step.total()))", "  print(display(step.twice().twice().size))"
      , "  return 0", "}" ]
    , "30\n20\n")
  ]

{-| Runtime failures inside a method body report at the method's own source. -}
methodRefusalPrograms :: [(String, Text)]
methodRefusalPrograms =
  [ ("an overflow inside a method keeps its span", program
      [ "trait Grow { fn grow(self: &Self) -> Int }"
      , "type Big = { value: Int }"
      , "impl Grow for Big { fn grow(self: &Self) -> Int { self.value + 1 } }"
      , "fn main() -> Int {", "  print(\"before\")"
      , "  Big{value: 9223372036854775807}.grow()", "}" ])
  , ("an inherited default fails at the trait's source", program
      [ "trait Half {"
      , "  fn value(self: &Self) -> Int"
      , "  fn half(self: &Self, by: Int) -> Int { self.value() / by }"
      , "}"
      , "type Ten = { n: Int }"
      , "impl Half for Ten { fn value(self: &Self) -> Int { self.n } }"
      , "fn main() -> Int {", "  print(display(Ten{n: 10}.half(2)))"
      , "  print(display(Ten{n: 10}.half(0)))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
