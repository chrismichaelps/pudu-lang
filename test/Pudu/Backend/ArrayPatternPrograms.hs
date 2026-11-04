{-| @Test.Backend.ArrayPatternPrograms — sortBy, sequence patterns and
    slicing by a range, against `Eval.Sort`, `Eval.Match` and `rangeBounds`. -}
module Pudu.Backend.ArrayPatternPrograms (arrayPatternSuccessPrograms, arrayPatternRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

arrayPatternSuccessPrograms :: [(String, Text, Text)]
arrayPatternSuccessPrograms =
  [ ("sortBy asks its comparison what sortWith asks, in that order", program
      [ "type Card = { rank: Int, name: Str }", "", "fn asked(a: Int, b: Int) -> Bool {"
      , "  print(display(a) + \"<\" + display(b))", "  a < b", "}"
      , "", "fn main() -> Int {", "  print(show([5, 3, 8, 1, 9, 2, 7].sortBy(asked)))"
      , "  print(show([1, 2, 3, 4].sortBy(asked)))", "  print(show([4, 3, 2, 1].sortBy(asked)))", "  let none: Array[Int] = []"
      , "  print(show(none.sortBy(asked)) + \" \" + show([7].sortBy(asked)))", "  let cards = [Card{rank: 2, name: \"a\"}, Card{rank: 1, name: \"b\"}, Card{rank: 2, name: \"c\"}, Card{rank: 1, name: \"d\"}, Card{rank: 3, name: \"e\"}]", "  print(show(cards.sortBy(|x, y| x.rank < y.rank).map(|c: Card| c.name)))"
      , "  print(show([\"pear\", \"fig\", \"apple\", \"kiwi\"].sortBy(|x: Str, y: Str| x.length() < y.length())))", "  var big: Array[Int] = []", "  var i = 0"
      , "  while i < 300 {", "    big = big.push((i * 7919) % 101)", "    i = i + 1"
      , "  }", "  let ordered = big.sortBy(|x, y| x < y)", "  print(display(ordered[0]) + \" \" + display(ordered[299]) + \" \" + display(ordered.length()))"
      , "  return 0", "}" ]
    , "3<5\n8<3\n1<8\n9<1\n2<9\n7<2\n1<3\n8<3\n8<5\n7<2\n7<9\n2<1\n2<3\n7<3\n7<5\n7<8\n9<8\n[1, 2, 3, 5, 7, 8, 9]\n2<1\n3<2\n4<3\n[1, 2, 3, 4]\n3<4\n2<3\n1<2\n[1, 2, 3, 4]\n[] [7]\n[\"b\", \"d\", \"a\", \"c\", \"e\"]\n[\"fig\", \"pear\", \"kiwi\", \"apple\"]\n0 100 300\n")
  , ("sequence patterns read the front, the back and the rest", program
      [ "type Card = { rank: Int, name: Str }", "", "fn shape(items: Array[Int]) -> Str {"
      , "  match items {", "    case [] => \"empty\"", "    case [only] => \"one \" + display(only)"
      , "    case [a, b] => \"two \" + display(a + b)", "    case [first, ..middle, last] => \"many \" + display(first) + \" \" + show(middle) + \" \" + display(last)", "    case _ => \"unreachable\""
      , "  }", "}", ""
      , "fn tail(items: Array[Str]) -> Str {", "  match items {", "    case [_, ..rest] => show(rest)"
      , "    case _ => \"none\"", "  }", "}"
      , "", "fn ends(items: Array[Int]) -> Str {", "  match items {"
      , "    case [.., 0] => \"ends zero\"", "    case [1, ..] => \"starts one\"", "    case [x, y, ..] if x > y => \"falls\""
      , "    case _ => \"other\"", "  }", "}"
      , "", "fn cards(items: Array[Card]) -> Str {", "  match items {"
      , "    case [Card{rank: 1, name}, ..others] => name + \" leads \" + display(others.length())", "    case [.., Card{name, rank}] => name + \" last \" + display(rank)", "    case _ => \"no cards\""
      , "  }", "}", ""
      , "fn nested(items: Array[Array[Int]]) -> Str {", "  match items {", "    case [[a, ..], [.., b]] => display(a * b)"
      , "    case [[], ..rest] => \"empty head \" + show(rest)", "    case _ => \"nested other\"", "  }"
      , "}", "", "fn main() -> Int {"
      , "  print(shape([]))", "  print(shape([4]))", "  print(shape([4, 5]))"
      , "  print(shape([1, 2, 3]))", "  print(shape([1, 2, 3, 4, 5]))", "  print(tail([\"a\", \"b\", \"c\"]))"
      , "  print(tail([\"a\"]))", "  print(tail([]))", "  print(ends([3, 0]))"
      , "  print(ends([1, 2]))", "  print(ends([5, 2, 9]))", "  print(ends([2]))"
      , "  print(ends([]))", "  print(cards([Card{rank: 1, name: \"ace\"}, Card{rank: 5, name: \"five\"}]))", "  print(cards([Card{rank: 3, name: \"three\"}, Card{rank: 5, name: \"five\"}]))"
      , "  print(cards([]))", "  print(nested([[2, 9], [7, 3]]))", "  print(nested([[], [1], [2]]))"
      , "  print(nested([[1]]))", "  let words = [\"x\", \"y\", \"z\"]", "  match words {"
      , "    case [head, ..more] => print(head + show(more) + show(words))", "    case _ => print(\"nothing\")", "  }"
      , "  return 0", "}" ]
    , "empty\none 4\ntwo 9\nmany 1 [2] 3\nmany 1 [2, 3, 4] 5\n[\"b\", \"c\"]\n[]\nnone\nends zero\nstarts one\nfalls\nother\nother\nace leads 1\nfive last 5\nno cards\n6\nempty head [[1], [2]]\nnested other\nx[\"y\", \"z\"][\"x\", \"y\", \"z\"]\n")
  , ("sequence patterns nest inside tuples, variants and loop bodies", program
      [ "type Hand = Cards(Array[Str]) | Empty", "", "fn pick(pair: (Array[Int], Int)) -> Int {"
      , "  match pair {", "    case ([a, ..], n) => a + n", "    case (_, n) => n"
      , "  }", "}", ""
      , "fn hand(h: Hand) -> Str {", "  match h {", "    case Cards([top, ..rest]) => top + \"/\" + display(rest.length())"
      , "    case Cards(_) => \"bare\"", "    case Empty => \"empty\"", "  }"
      , "}", "", "fn main() -> Int {"
      , "  print(display(pick(([4, 5], 1))) + \" \" + display(pick(([], 7))))", "  print(hand(Cards([\"k\", \"q\"])) + \" \" + hand(Cards([])) + \" \" + hand(Empty))", "  let grid = [[1, 2], [3, 4]]"
      , "  for row in grid {", "    match row {", "      case [l, r] => print(display(l * r))"
      , "      case _ => print(\"?\")", "    }", "  }"
      , "  let found = match [1, 2, 3] {", "    case [_, ..tail] => tail", "    case _ => []"
      , "  }", "  print(show(found.push(9)))", "  return 0"
      , "}" ]
    , "5 7\nk/1 bare empty\n2\n12\n[2, 3, 9]\n")
  , ("slicing by a written range, on arrays and on Str", program
      [ "fn noted(label: Str, value: Int) -> Int {", "  print(label)", "  value"
      , "}", "", "fn main() -> Int {"
      , "  let items = [10, 20, 30, 40, 50]", "  print(show(items[1..3]) + \" \" + show(items[1..=3]) + \" \" + show(items[..2]) + \" \" + show(items[3..]) + \" \" + show(items[..]))", "  print(show(items[0..0]) + \" \" + show(items[5..]) + \" \" + show(items[2..=1]) + \" \" + show(items[..=4]) + \" \" + show(items[5..5]))"
      , "  let words = [\"a\", \"b\", \"c\"]", "  let tail = words[1..]", "  print(show(tail.push(\"d\")) + show(words))"
      , "  let text = \"héllo wörld\"", "  print(text[0..5] + \"|\" + text[6..] + \"|\" + text[..=1] + \"|\" + text[11..] + \"|\" + text[3..3])", "  let grid = [[1, 2], [3, 4], [5, 6]]"
      , "  print(show(grid[1..][0]))", "  print(show(items[noted(\"a\", 1)..noted(\"b\", 2)]))", "  return 0"
      , "}" ]
    , "[20, 30] [20, 30, 40] [10, 20] [40, 50] [10, 20, 30, 40, 50]\n[] [] [] [10, 20, 30, 40, 50] []\n[\"b\", \"c\", \"d\"][\"a\", \"b\", \"c\"]\nhéllo|wörld|hé||\n[3, 4]\na\nb\n[20]\n")
  ]

{-| Each fails where `rangeBounds` or `readIndex` fails, after the output
    that came before it. -}
arrayPatternRefusalPrograms :: [(String, Text)]
arrayPatternRefusalPrograms =
  [ ("a slice past the end names the length", program
      [ "fn main() -> Int {", "  let items = [1, 2, 3]", "  print(show(items[1..2]))"
      , "  print(show(items[2..4]))", "  return 0", "}" ])
  , ("a slice ending before it starts", program
      [ "fn main() -> Int {", "  let items = [1, 2, 3]", "  let low = 2"
      , "  print(show(items[low..1]))", "  return 0", "}" ])
  , ("a Str slice counts characters, not bytes", program
      [ "fn main() -> Int {", "  let text = \"héllo\"", "  print(text[1..=5])"
      , "  return 0", "}" ])
  , ("a negative slice start", program
      [ "fn main() -> Int {", "  let items: Array[Int] = []", "  let back = -1"
      , "  print(show(items[back..]))", "  return 0", "}" ])
  , ("a Str index past the end fails at the index", program
      [ "fn main() -> Int {", "  let text = \"héllo\"", "  print(display(text[1]) + display(text[4]))"
      , "  print(display(text[5]))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
