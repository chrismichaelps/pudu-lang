{-| @Test.Backend.RangePrograms — range values against `Eval.Range`. -}
module Pudu.Backend.RangePrograms (rangeSuccessPrograms, rangeRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

rangeSuccessPrograms :: [(String, Text, Text)]
rangeSuccessPrograms =
  [ ("every range shape, method, rendering, comparison, iteration and slice", program
      [ "fn noted(n: Int) -> Int {", "  print(\"f\" + display(n))", "  n * n"
      , "}", "", "fn span(low: Int, high: Int) -> Range[Int] { low..=high }"
      , "", "fn main() -> Int {", "  let a = 1..5"
      , "  let b = 1..=5", "  let c = 3..", "  let d = ..4"
      , "  let e = ..", "  let empty = 5..2", "  print(show(a) + \" \" + show(b) + \" \" + show(c) + \" \" + show(d) + \" \" + show(e) + \" \" + show(empty) + \" \" + display(a))"
      , "  print(display(a.length()) + \" \" + display(b.length()) + \" \" + display(empty.length()) + \" \" + display((3..3).length()) + \" \" + display((3..=3).length()))", "  print(display(a.isEmpty()) + display(empty.isEmpty()) + display(c.isEmpty()) + display((2..2).isEmpty()) + display((2..=2).isEmpty()))", "  print(display(a.contains(1)) + display(a.contains(5)) + display(b.contains(5)) + display(c.contains(-9)) + display(c.contains(3)) + display(d.contains(4)) + display(e.contains(0)))"
      , "  print(show(a.start()) + show(a.end()) + show(c.end()) + show(d.start()) + show(e.start()))", "  print(display(a.isInclusive()) + display(b.isInclusive()) + display(a.isBounded()) + display(c.isBounded()) + display(d.isBounded()) + display(e.isBounded()))", "  print(show(a.toArray()) + show(b.reverse()) + show(empty.toArray()) + show((0..10).step(3)) + show((0..=10).step(5)) + show((0..3).step(100)))"
      , "  print(display(b.sum()) + \" \" + display(empty.sum()) + \" \" + display((-5..=5).sum()) + \" \" + display((-3..0).sum()))", "  print(show(b.map(noted)) + \" \" + show(b.filter(|n| n % 2 == 0)) + \" \" + display(b.reduce(|acc, n| acc * n, 1)))", "  for i in span(2, 4) { print(\"i\" + display(i)) }"
      , "  for i in empty { print(\"never\") }", "  let items = [10, 20, 30, 40, 50]", "  print(show(items[a]) + \" \" + show(items[c]) + \" \" + show(items[d]) + \" \" + show(items[e]) + \" \" + \"héllo\"[1..=3])"
      , "  print(display(a == 1..5) + display(a == b) + display(c == 3..) + display(e == ..) + display(a != b))", "  print(display((a, 0) < (b, 0)) + display((c, 0) < (a, 0)) + display((d, 0) < (a, 0)) + display((1..3, 0) < (1..4, 0)))", "  let keyed = mapOf([(1..3, \"x\"), (..2, \"y\"), (0..=1, \"z\")])"
      , "  print(show(keyed) + \" \" + show(setOf([3.., 1..2, ..])))", "  let big = (-9223372036854775807 - 1)..=9223372036854775806", "  print(display(big.isBounded()) + \" \" + display((0..9223372036854775807).length()) + \" \" + display((-1..9223372036854775806).length()))"
      , "  return 0", "}" ]
    , "1..5 1..=5 3.. ..4 .. 5..2 1..5\n4 5 0 0 1\nfalsetruefalsetruefalse\ntruefalsetruefalsetruefalsetrue\nSome(1)Some(5)NoneNoneNone\nfalsetruetruefalsefalsefalse\n[1, 2, 3, 4][5, 4, 3, 2, 1][][0, 3, 6, 9][0, 5, 10][0]\n15 0 0 -6\nf1\nf2\nf3\nf4\nf5\n[1, 4, 9, 16, 25] [2, 4] 120\ni2\ni3\ni4\n[20, 30, 40, 50] [40, 50] [10, 20, 30, 40] [10, 20, 30, 40, 50] éll\ntruefalsetruetruetrue\ntruefalsetruetrue\n{..2: \"y\", 0..=1: \"z\", 1..3: \"x\"} #{.., 1..2, 3..}\ntrue 9223372036854775807 9223372036854775807\n")
  ]

{-| Each fails where `Eval.Range` fails, after printing "start". -}
rangeRefusalPrograms :: [(String, Text)]
rangeRefusalPrograms =
  [ ("length of an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(display((3..).length()))"
      , "  return 0", "}" ])
  , ("a length past Int", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(display((-9223372036854775807 - 1..=9223372036854775807).length()))"
      , "  return 0", "}" ])
  , ("a sum past Int", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(display((9223372036854775800..=9223372036854775807).sum()))"
      , "  return 0", "}" ])
  , ("a step of zero", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(show((0..10).step(0)))"
      , "  return 0", "}" ])
  , ("toArray of an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(show((..4).toArray()))"
      , "  return 0", "}" ])
  , ("map of an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(show((..4).map(|n| n)))"
      , "  return 0", "}" ])
  , ("for over an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let open = 7.."
      , "  for i in open { print(display(i)) }", "  return 0", "}" ])
  , ("a range value past the end of an array", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let r = 2..9"
      , "  print(show([1, 2, 3][r]))", "  return 0", "}" ])
  , ("an inclusive range value past the end", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let r = ..=3"
      , "  print(show([1, 2, 3][r]))", "  return 0", "}" ])
  , ("a Str range value ending before it starts", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let r = 3..1"
      , "  print(\"abc\"[r])", "  return 0", "}" ])
  , ("sum of an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(display((..5).sum()))"
      , "  return 0", "}" ])
  , ("reverse of an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(show((1..).reverse()))"
      , "  return 0", "}" ])
  , ("a negative step on an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(show((..).step(-2)))"
      , "  return 0", "}" ])
  , ("filter of an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(show((..).filter(|n| n > 0)))"
      , "  return 0", "}" ])
  , ("reduce of an unbounded range", program
      [ "fn main() -> Int {", "  print(\"start\")", "  print(display((..).reduce(|a, n| a + n, 0)))"
      , "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
