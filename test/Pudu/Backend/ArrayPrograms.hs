{-| @Test.Backend.ArrayPrograms — arrays against `Eval.Array` and the
    evaluator's method dispatch. -}
module Pudu.Backend.ArrayPrograms (arraySuccessPrograms, arrayRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

arraySuccessPrograms :: [(String, Text, Text)]
arraySuccessPrograms =
  [ ("reading methods, rendering and literals", program
      [ "fn main() -> Int {"
      , "  let empty: Array[Int] = []", "  let numbers = [3, 1, 2]"
      , "  print(show(numbers) + \" \" + show(empty) + \" \" + display(numbers.length()) + \" \" + display(empty.isEmpty()))"
      , "  print(display(numbers.get(1)) + \" \" + display(numbers[2]) + \" \" + display(numbers.indexOf(2)) + \" \" + display(numbers.indexOf(9)) + \" \" + display(numbers.contains(3)))"
      , "  print(show([\"a\", \"b\"]) + \" \" + display([\"a\"]) + \" \" + [\"a\", \"b\", \"c\"].join(\"-\") + \"|\" + [].join(\",\") + \"|\" + [\"solo\"].join(\", \"))"
      , "  return 0", "}" ]
    , "[3, 1, 2] [] 3 true\n1 2 2 -1 true\n[\"a\", \"b\"] [\"a\"] a-b-c||solo\n")
  , ("updates clamp and leave the original alone", program
      [ "fn main() -> Int {"
      , "  let numbers = [3, 1, 2]", "  let empty: Array[Int] = []"
      , "  print(show(numbers.push(4)) + \" \" + show(numbers.pop()) + \" \" + show(empty.pop()) + \" \" + show(numbers))"
      , "  print(show(numbers.insert(0, 9)) + \" \" + show(numbers.insert(-5, 8)) + \" \" + show(numbers.insert(99, 7)) + \" \" + show(numbers.insert(2, 6)))"
      , "  print(show(numbers.remove(1)) + \" \" + show(numbers.remove(-1)) + \" \" + show(numbers.remove(3)))"
      , "  print(show(numbers.slice(1, 3)) + \" \" + show(numbers.slice(-4, 2)) + \" \" + show(numbers.slice(2, 1)) + \" \" + show(numbers.slice(0, 99)))"
      , "  print(show(numbers.concat([5, 6])) + \" \" + show(numbers.reverse()) + \" \" + show(numbers))"
      , "  return 0", "}" ]
    , "[3, 1, 2, 4] [3, 1] [] [3, 1, 2]\n[9, 3, 1, 2] [8, 3, 1, 2] [3, 1, 2, 7] [3, 1, 6, 2]\n[3, 2] [3, 1, 2] [3, 1, 2]\n[1, 2] [3, 1] [] [3, 1, 2]\n[3, 1, 2, 5, 6] [2, 1, 3] [3, 1, 2]\n")
  , ("a variable updated in place never changes a copy taken earlier", program
      [ "fn main() -> Int {"
      , "  var items = [\"a\"]", "  let early = items"
      , "  items = items.push(\"b\")", "  let middle = items"
      , "  items = items.push(\"c\")", "  items = items.insert(0, \"z\")", "  items = items.remove(1)"
      , "  items = items.concat(items)", "  items = items.pop()"
      , "  print(show(early) + \" \" + show(middle) + \" \" + show(items))"
      , "  var built: Array[Int] = []", "  var i = 0"
      , "  while i < 2000 {", "    built = built.push(i)", "    i = i + 1", "  }"
      , "  var total = 0", "  for value in built { total = total + value }"
      , "  print(display(built.length()) + \" \" + display(total))"
      , "  return 0", "}" ]
    , "[\"a\"] [\"a\", \"b\"] [\"z\", \"b\", \"c\", \"z\", \"b\"]\n2000 1999000\n")
  , ("map, filter and reduce call back once per item, in order", program
      [ "fn noted(label: Str, value: Int) -> Int {", "  print(label + display(value))", "  value", "}"
      , "fn main() -> Int {"
      , "  let numbers = [3, 1, 2]"
      , "  print(show(numbers.map(|n| noted(\"m\", n) * 10)))"
      , "  print(show(numbers.filter(|n| noted(\"f\", n) > 1)))"
      , "  print(display(numbers.reduce(|acc, n| noted(\"r\", acc) + n, 100)))"
      , "  print(show(numbers.map(|n| [n, n])) + \" \" + show([\"x\", \"yy\"].map(|w: Str| w.length())))"
      , "  let none: Array[Int] = []", "  print(show(none.map(|n| n + 1)) + \" \" + display(none.reduce(|a, b| a + b, 7)))"
      , "  return 0", "}" ]
    , "m3\nm1\nm2\n[30, 10, 20]\nf3\nf1\nf2\n[3, 2]\nr100\nr103\nr104\n106\n[[3, 3], [1, 1], [2, 2]] [1, 2]\n[] 7\n")
  , ("arrays of records, nested arrays, equality and ordering inside tuples", program
      [ "type Point = { x: Int }"
      , "fn main() -> Int {"
      , "  let points = [Point{x: 1}, Point{x: 2}]"
      , "  print(show(points) + \" \" + display(points == [Point{x: 1}, Point{x: 2}]) + \" \" + display(points != []))"
      , "  let nested = [[1, 2], [], [3]]", "  print(show(nested) + \" \" + display(nested[0][1]))"
      , "  print(display(([1, 2], 3) < ([1, 3], 0)) + \" \" + display(([2], 0) < ([1, 9], 9)) + \" \" + display(([1], 0) < ([1, 0], 0)))"
      , "  for point in points { print(display(point.x)) }"
      , "  return 0", "}" ]
    , "[Point{x: 1}, Point{x: 2}] true true\n[[1, 2], [], [3]] 2\ntrue false true\n1\n2\n")
  , ("an entry may return an array", program
      [ "fn main() -> Array[Str] {", "  [\"done\", \"x\"]", "}" ]
    , "[\"done\", \"x\"]\n")
  ]

{-| Failures report where the evaluator reports them: `get` at the call, an
    index at the index, an ordering at the operation. -}
arrayRefusalPrograms :: [(String, Text)]
arrayRefusalPrograms =
  [ ("get past the end fails at the call", program
      [ "fn main() -> Int {", "  let items = [1, 2]", "  print(display(items.get(1)))"
      , "  print(display(items.get(2)))", "  return 0", "}" ])
  , ("a negative index fails at the index", program
      [ "fn main() -> Int {", "  let items = [1, 2]", "  print(display(items[0]))"
      , "  print(display(items[-1]))", "  return 0", "}" ])
  , ("arrays are not ordered", program
      [ "fn main() -> Int {", "  print(\"before\")", "  print(display([1] < [2]))", "  return 0", "}" ])
  , ("a failure inside a callback keeps its span", program
      [ "fn main() -> Int {", "  let items = [1, 9223372036854775807]"
      , "  print(show(items.map(|n| n + 1)))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
