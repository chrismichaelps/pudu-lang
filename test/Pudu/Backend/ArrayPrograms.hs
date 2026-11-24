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
  , ("empty arrays of non-text elements can join directly and through a value", program
      [ "fn main() -> Int {"
      , "  let numbers: Array[Int] = []"
      , "  let flags: Array[Bool] = []"
      , "  let join = flags.join"
      , "  print(\"[\" + numbers.join({ print(\"separator\")\n \",\" }) + \"]\")"
      , "  print(\"[\" + join(\"/\") + \"]\")"
      , "  return 0", "}" ]
    , "separator\n[]\n[]\n")
  , ("dynamic arrays join the held text variants", program
      (dynamicJoinTypes <>
        [ "fn main() -> Int {"
        , "  let empty: Array[dynamic Marked] = []"
        , "  let values: Array[dynamic Marked] = [\"é\", \"\", \"x\"]"
        , "  let join = values.join"
        , "  print(\"[\" + empty.join(\",\") + \"]\")"
        , "  print(join(\"/\"))"
        , "  return 0", "}" ])
    , "[]\né//x\n")
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
      , "  while i < 2000 {", "    built = built.push(i % 13)", "    i = i + 1", "  }"
      , "  var total = 0", "  for value in built { total = total + value }"
      , "  print(display(built.length()) + \" \" + display(total))"
      , "  let original = built", "  built = built.push(i % 13)"
      , "  print(display(original.length()) + \" \" + display(built[2000]))"
      , "  return 0", "}" ]
    , "[\"a\"] [\"a\", \"b\"] [\"z\", \"b\", \"c\", \"z\", \"b\"]\n2000 11989\n2000 11\n")
  , ("array updates and callbacks retain the receiver before operands", program
      [ "fn items() -> Array[Int] { print(\"array\")\n [1, 2] }"
      , "fn callback() -> fn(Int) -> Int { print(\"callback\")\n |n| n + 1 }"
      , "fn main() -> Int {"
      , "  var xs = [1, 2]"
      , "  xs = xs.push(xs[0])"
      , "  print(show(xs))"
      , "  xs = xs.push({ xs = [9]\n xs[0] })"
      , "  print(show(xs))"
      , "  print(show(items().map(callback())))"
      , "  0", "}" ]
    , "[1, 2, 1]\n[1, 2, 1, 9]\narray\ncallback\n[2, 3]\n")
  , ("indexing preserves owned elements and snapshots effectful receivers", program
      [ "fn main() -> Int {"
      , "  var rows = [[1], [2]]", "  let position = 1", "  let saved = rows[position]"
      , "  rows[1] = [8]", "  print(show(saved))"
      , "  print(show(rows[{ rows = [[9]]\n 0 }]))"
      , "  print(show(rows))", "  0", "}" ]
    , "[2]\n[1]\n[[9]]\n")
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
  , ("sortBy asks an annotated tuple comparison at every merge step", program
      [ "type Entry = { neededAt: Int }"
      , "fn main() -> Int {"
      , "  let entries: Array[(Str, Entry)] = [(\"a\", Entry{neededAt: 1}), (\"c\", Entry{neededAt: 2}), (\"b\", Entry{neededAt: 3})]"
      , "  let sorted = entries.sortBy(|left: (Str, Entry), right: (Str, Entry)| left[1].neededAt > right[1].neededAt)"
      , "  print(show(sorted.map(|pair| pair[0])))"
      , "  return 0", "}" ]
    , "[\"b\", \"c\", \"a\"]\n")
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
  , ("a failing append argument reports its original diagnostic", program
      [ "fn main() -> Int {", "  var items = [1, 2]", "  let divisor = items[0] - 1"
      , "  print(show(items))", "  items = items.push(12 % divisor)"
      , "  return 0", "}" ])
  , ("arrays are not ordered", program
      [ "fn main() -> Int {", "  print(\"before\")", "  print(display([1] < [2]))", "  return 0", "}" ])
  , ("non-text join evaluates the receiver and separator before refusing", program
      [ "fn items() -> Array[Int] { print(\"receiver\")\n [1] }"
      , "fn separator() -> Str { print(\"separator\")\n \":\" }"
      , "fn main() -> Int {", "  print(items().join(separator()))", "  return 0", "}" ])
  , ("bound non-text join blames the call through the method value", program
      [ "fn main() -> Int {", "  let join = [1].join"
      , "  print(join({ print(\"separator\")\n \":\" }))", "  return 0", "}" ])
  , ("dynamic join rejects the first member that does not hold text", program
      (dynamicJoinTypes <>
        [ "fn main() -> Int {"
        , "  let values: Array[dynamic Marked] = [\"text\", Marker{}]"
        , "  print(values.join({ print(\"separator\")\n \":\" }))"
        , "  return 0", "}" ]))
  , ("a unit array member triggers the invalid-member diagnostic", program
      [ "fn main() -> Int {", "  print(\"before\")"
      , "  print([()].join(\",\"))", "  return 0", "}" ])
  , ("array negation reports E7001 after evaluating the operand", program
      [ "fn main() -> Int {", "  let invalid = -{ print(\"array\")\n [1] }"
      , "  print(show(invalid))", "  return 0", "}" ])
  , ("a failure inside a callback keeps its span", program
      [ "fn main() -> Int {", "  let items = [1, 9223372036854775807]"
      , "  print(show(items.map(|n| n + 1)))", "  return 0", "}" ])
  ]

dynamicJoinTypes :: [Text]
dynamicJoinTypes =
  [ "trait Marked { fn mark(self: &Self) -> Int }"
  , "type Marker = {}"
  , "impl Marked for Str { fn mark(self: &Self) -> Int { 1 } }"
  , "impl Marked for Marker { fn mark(self: &Self) -> Int { 2 } }"
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
