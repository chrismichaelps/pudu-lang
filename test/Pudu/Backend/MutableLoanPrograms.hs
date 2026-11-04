{-| @Test.Backend.MutableLoanPrograms — `&mut` parameters: the place lent to
    a call is read where its argument stands and written back after the call,
    by every way the callee finishes. -}
module Pudu.Backend.MutableLoanPrograms
  ( mutableLoanSuccessPrograms, mutableLoanRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

mutableLoanSuccessPrograms :: [(String, Text, Text, Text)]
mutableLoanSuccessPrograms =
  [ ("locals, fields, elements and nested places are lent and written back", program
      [ "type Point = { mut x: Int, y: Int }"
      , "fn bump(value: &mut Int) -> Int {"
      , "  *value = *value + 1"
      , "  *value * 10"
      , "}"
      , "fn shift(point: &mut Point) { (*point).x = (*point).x + 100 }"
      , "fn main() -> Int {"
      , "  var n = 1"
      , "  let r = bump(&mut n)"
      , "  print(display(n) + \" \" + display(r))"
      , "  var p = Point{x: 1, y: 2}"
      , "  shift(&mut p)"
      , "  bump(&mut p.x)"
      , "  var list = [1, 2, 3]"
      , "  bump(&mut list[1])"
      , "  var points = [Point{x: 1, y: 1}, Point{x: 2, y: 2}]"
      , "  bump(&mut points[1].x)"
      , "  var grid = [[1, 2], [3]]"
      , "  bump(&mut grid[0][1])"
      , "  print(show(p) + show(list) + show(points) + show(grid))"
      , "  0"
      , "}" ]
    , "2 20\nPoint{x: 102, y: 2}[1, 3, 3][Point{x: 1, y: 1}, Point{x: 3, y: 2}][[1, 3], [3]]\n", "")
  , ("early return, ? and loops write the final value back", program
      [ "fn early(value: &mut Int, stop: Bool) -> Int {"
      , "  *value = 5"
      , "  if stop { return 1 }"
      , "  *value = 6"
      , "  2"
      , "}"
      , "fn trial(value: &mut Int, input: Result[Int, Str]) -> Result[Int, Str] {"
      , "  *value = 7"
      , "  let got = input?"
      , "  *value = got"
      , "  Ok(got + 1)"
      , "}"
      , "fn find(value: &mut Int, input: Option[Int]) -> Option[Int] {"
      , "  *value = *value + 1"
      , "  let got = input?"
      , "  Some(got * 2)"
      , "}"
      , "fn count(value: &mut Int, limit: Int) -> Int {"
      , "  while true {"
      , "    *value = *value + 1"
      , "    if *value >= limit { return *value }"
      , "  }"
      , "  0"
      , "}"
      , "fn reset(value: &mut Int) {"
      , "  *value = 0"
      , "  return"
      , "}"
      , "fn main() -> Int {"
      , "  var n = 0"
      , "  print(display(early(&mut n, true)) + \" \" + display(n))"
      , "  print(display(early(&mut n, false)) + \" \" + display(n))"
      , "  print(show(trial(&mut n, Err(\"no\"))) + \" \" + display(n))"
      , "  print(show(trial(&mut n, Ok(3))) + \" \" + display(n))"
      , "  var k = 0"
      , "  print(show(find(&mut k, None)) + show(find(&mut k, Some(4))) + display(k))"
      , "  print(display(count(&mut k, 12) + count(&mut k, 15)) + \" \" + display(k))"
      , "  reset(&mut k)"
      , "  print(display(k))"
      , "  0"
      , "}" ]
    , "1 5\n2 6\nErr(\"no\") 7\nOk(4) 3\nNoneSome(8)2\n27 15\n0\n", "")
  , ("several loans, lending on, and index order", program
      [ "type Point = { mut x: Int, mut y: Int }"
      , "fn swap(a: &mut Int, b: &mut Int) {"
      , "  let t = *a"
      , "  *a = *b"
      , "  *b = t"
      , "}"
      , "fn bump(value: &mut Int) -> Int {"
      , "  *value = *value + 1"
      , "  *value"
      , "}"
      , "fn pass(value: &mut Int) -> Int { bump(value) + bump(value) }"
      , "fn tick(label: Str) -> Int {"
      , "  print(label)"
      , "  0"
      , "}"
      , "fn deep(value: &mut Int, depth: Int) -> Int {"
      , "  if depth == 0 { return *value }"
      , "  *value = *value + 1"
      , "  deep(value, depth - 1)"
      , "}"
      , "fn main() -> Int {"
      , "  var p = Point{x: 1, y: 2}"
      , "  swap(&mut p.x, &mut p.y)"
      , "  print(show(p))"
      , "  var n = 3"
      , "  print(display(pass(&mut n)) + \" \" + display(n))"
      , "  var grid = [[1, 2], [3]]"
      , "  bump(&mut grid[tick(\"i\")][tick(\"j\") + 1])"
      , "  print(show(grid))"
      , "  var d = 0"
      , "  print(display(deep(&mut d, 50)) + \" \" + display(d))"
      , "  0"
      , "}" ]
    , "Point{x: 2, y: 1}\n9 5\ni\nj\n[[1, 3], [3]]\n50 50\n", "")
  , ("defaults, generic copies and shadowing keep the loaned parameter", program
      [ "fn shadow(value: &mut Int) -> Int {"
      , "  *value = 3"
      , "  let other = 99"
      , "  other"
      , "}"
      , "fn append(value: &mut Str, suffix: Str = \"!\") { *value = *value + suffix }"
      , "fn first[T](list: &mut Array[T], fallback: T) -> T {"
      , "  let got = list[0]"
      , "  *list = [fallback]"
      , "  got"
      , "}"
      , "fn main() -> Int {"
      , "  var n = 1"
      , "  print(display(shadow(&mut n)) + \" \" + display(n))"
      , "  var s = \"a\""
      , "  append(&mut s)"
      , "  append(&mut s, \"?\")"
      , "  print(s)"
      , "  var xs = [\"p\", \"q\"]"
      , "  print(first(&mut xs, \"z\") + show(xs))"
      , "  var ns = [4, 5]"
      , "  print(display(first(&mut ns, 0)) + show(ns))"
      , "  0"
      , "}" ]
    , "99 3\na!?\np[\"z\"]\n4[0]\n", "")
  , ("owned values lent in a loop are released", program
      [ "type Named = { mut name: Str, mut tags: Array[Str] }"
      , "fn grow(text: &mut Str, tags: &mut Array[Str]) -> Int {"
      , "  *text = (*text).slice(1, (*text).length()) + \"y\""
      , "  *tags = (*tags).push(*text)"
      , "  (*tags).length()"
      , "}"
      , "fn main() -> Int {"
      , "  var named = [Named{name: \"x\".repeat(64), tags: []}]"
      , "  var total = 0"
      , "  for index in 0..200 {"
      , "    var held = named[0].tags"
      , "    total = total + grow(&mut named[0].name, &mut held)"
      , "    named[0].tags = held"
      , "  }"
      , "  print(display(total) + \" \" + display(named[0].tags.length()) + \" \" + named[0].name.slice(60, 64))"
      , "  0"
      , "}" ]
    , "20100 200 yyyy\n", "")
  ]

mutableLoanRefusalPrograms :: [(String, Text)]
mutableLoanRefusalPrograms =
  [ ("a lent element out of range fails at the root name before the call", program
      [ "fn bump(value: &mut Int) -> Int {"
      , "  print(\"called\")"
      , "  *value = *value + 1"
      , "  *value"
      , "}"
      , "fn main() -> Int {"
      , "  var grid = [[1], [2]]"
      , "  bump(&mut grid[1][0])"
      , "  print(show(grid))"
      , "  bump(&mut grid[3][0])"
      , "  0"
      , "}" ])
  , ("a failure in the callee ends the program before any write", program
      [ "fn fail(value: &mut Int, divisor: Int) -> Int {"
      , "  *value = 9"
      , "  *value / divisor"
      , "}"
      , "fn main() -> Int {"
      , "  var n = 1"
      , "  print(display(fail(&mut n, 1)) + \" \" + display(n))"
      , "  fail(&mut n, 0)"
      , "  0"
      , "}" ])
  , ("loaned recursion past the call depth fails like any call", program
      [ "fn deep(value: &mut Int, depth: Int) -> Int {"
      , "  if depth == 0 { return *value }"
      , "  *value = *value + 1"
      , "  deep(value, depth - 1)"
      , "}"
      , "fn main() -> Int {"
      , "  var d = 0"
      , "  deep(&mut d, " <> Text.pack (show (callDepthLimit + 5)) <> ")"
      , "}" ])
  , ("an index that stops leaves the call unmade", program
      [ "fn bump(value: &mut Int) -> Int {"
      , "  print(\"called\")"
      , "  *value"
      , "}"
      , "fn main() -> Int {"
      , "  var list = [1]"
      , "  bump(&mut list[panic(\"stop\")])"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
