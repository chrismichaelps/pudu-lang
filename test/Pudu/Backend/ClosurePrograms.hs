{-| @Test.Backend.ClosurePrograms — lambdas, captures, function values and
    calls through them. -}
module Pudu.Backend.ClosurePrograms (closureSuccessPrograms, closureRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

closureSuccessPrograms :: [(String, Text, Text)]
closureSuccessPrograms =
  [ ("captures copy what a lambda mentions when it is evaluated", program
      [ "type Point = { x: Int, y: Int }"
      , "fn main() -> Int {"
      , "  var label = \"before\"", "  var point = Point{x: 1, y: 2}"
      , "  let shout = fn(text: Str) -> Str => text + \"! \" + label + \" \" + show(point)"
      , "  label = \"after\"", "  point = Point{x: 9, y: 9}"
      , "  print(shout(\"hi\"))", "  print(label + \" \" + show(point))"
      , "  return 0", "}" ]
    , "hi! before Point{x: 1, y: 2}\nafter Point{x: 9, y: 9}\n")
  , ("closures pass through generic functions and come back out", program
      [ "fn apply[T, U](value: T, f: fn(T) -> U) -> U { f(value) }"
      , "fn twice(f: fn(Int) -> Int, value: Int) -> Int { f(f(value)) }"
      , "fn adder(by: Int) -> fn(Int) -> Int { fn(n: Int) -> Int => n + by }"
      , "fn double(n: Int) -> Int { n * 2 }"
      , "fn compose(f: fn(Int) -> Int, g: fn(Int) -> Int) -> fn(Int) -> Int { |x| g(f(x)) }"
      , "fn main() -> Int {"
      , "  print(display(apply(3, |n| n + 1)) + \" \" + apply(\"pudu\", fn(t: Str) -> Int => t.length()).toText())"
      , "  let add5 = adder(5)"
      , "  print(display(add5(10)) + \" \" + display(twice(add5, 1)) + \" \" + display(twice(double, 3)))"
      , "  print(display(compose(add5, double)(1)) + \" \" + display(compose(double, add5)(1)))"
      , "  return 0", "}" ]
    , "4 4\n15 11 12\n12 7\n")
  , ("function values live in records and tuples and render as their names", program
      [ "type Holder = { name: Str, admits: fn(Str) -> Int }"
      , "fn double(n: Int) -> Int { n * 2 }"
      , "fn main() -> Int {"
      , "  let held = Holder{name: \"pudu\", admits: fn(reader: Str) -> Int { reader.length() }}"
      , "  let check = held.admits", "  print(display(check(\"reader\")))"
      , "  let named = double", "  let pair = (1, |n| n * 3)"
      , "  print(display(named(21)) + \" \" + display(pair[1](4)))"
      , "  print(show(named) + \" \" + show(pair[1]) + \" \" + display(double))"
      , "  return 0", "}" ]
    , "6\n42 12\n<fn double> <fn <fn>> <fn double>\n")
  , ("function values are equal when written in the same place", program
      [ "fn double(n: Int) -> Int { n * 2 }"
      , "fn make(by: Int) -> fn(Int) -> Int { |n| n + by }"
      , "fn main() -> Int {"
      , "  let first = make(1)", "  let second = make(2)", "  let other = |n| n + 1"
      , "  print(display(first == second) + \" \" + display(first == other) + \" \" + display(double == double))"
      , "  let named: fn(Int) -> Int = double"
      , "  print(display(named == first) + \" \" + display(named != first))"
      , "  return 0", "}" ]
    , "true false true\nfalse true\n")
  , ("lambdas inside a generic body and recursion through a passed function", program
      [ "fn mapPair[T](pair: (T, T), f: fn(T) -> T) -> (T, T) {"
      , "  let both = |value: T| f(value)", "  (both(pair[0]), both(pair[1]))", "}"
      , "fn repeat(times: Int, f: fn(Int) -> Int, value: Int) -> Int {"
      , "  if times == 0 { value } else { repeat(times - 1, f, f(value)) }", "}"
      , "fn main() -> Int {"
      , "  print(show(mapPair((1, 2), |n| n * 10)) + \" \" + show(mapPair((\"a\", \"b\"), |t| t + t)))"
      , "  print(display(repeat(5, |n| n * 2, 1)))"
      , "  let outer = |a: Int| fn(b: Int) -> Int => a * 100 + b"
      , "  print(display(outer(3)(4)))"
      , "  return 0", "}" ]
    , "(10, 20) (\"aa\", \"bb\")\n32\n304\n")
  , ("arguments run before the callee value", program
      [ "fn tag(label: Str, value: Int) -> Int {", "  print(label)", "  value", "}"
      , "fn pick(label: Str) -> fn(Int) -> Int {", "  print(label)", "  |n| n + 1", "}"
      , "fn main() -> Int {"
      , "  print(display(pick(\"callee\")(tag(\"argument\", 1))))"
      , "  var f = |n: Int| n * 2"
      , "  print(display(f({ f = |n: Int| n * 3", "    5 })))"
      , "  return 0", "}" ]
    , "argument\ncallee\n2\n15\n")
  ]

{-| Failures inside a lambda report at the lambda's own source. -}
closureRefusalPrograms :: [(String, Text)]
closureRefusalPrograms =
  [ ("ordering a tuple that holds a function refuses after both sides ran", program
      [ "fn side(label: Str, f: fn(Int) -> Int) -> (Int, fn(Int) -> Int) {", "  print(label)", "  (1, f)", "}"
      , "fn main() -> Int {"
      , "  let absent: Option[fn(Int) -> Int] = None"
      , "  print(display((1, absent) <= (1, absent)))"
      , "  print(display(side(\"left\", |n| n) < side(\"right\", |n| n + 1)))", "  return 0", "}" ])
  , ("an overflow inside a lambda keeps its span", program
      [ "fn apply(f: fn(Int) -> Int, value: Int) -> Int { f(value) }"
      , "fn main() -> Int {", "  print(display(apply(|n| n + 1, 1)))"
      , "  print(display(apply(|n| n * 9223372036854775807, 2)))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
