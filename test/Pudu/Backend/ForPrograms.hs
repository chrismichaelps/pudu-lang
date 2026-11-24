{-| @Test.Backend.ForPrograms — `for` over written ranges and sequences. -}
module Pudu.Backend.ForPrograms (forSuccessPrograms, forRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

countdown :: [Text]
countdown =
  [ "trait Sequence[S, T] {"
  , "  fn begin(self: &Self) -> S"
  , "  fn advance(self: &Self, state: S) -> Option[(S, T)]"
  , "}"
  , "type Countdown = { from: Int }"
  , "impl Sequence[Int, Str] for Countdown {"
  , "  fn begin(self: &Self) -> Int { self.from }"
  , "  fn advance(self: &Self, state: Int) -> Option[(Int, Str)] {"
  , "    if state == 0 { None } else { Some((state - 1, \"t\" + display(state))) }"
  , "  }"
  , "}" ]

sequenceView :: Text -> Text -> Text -> Text -> [Text]
sequenceView checked checkedBody held heldBody =
  [ "trait View { fn size(self: &Self) -> Int }"
  , "impl View for Str { fn size(self: &Self) -> Int { self.length() } }"
  , "impl View for Bytes { fn size(self: &Self) -> Int { 0 } }"
  , "fn select(value: dynamic View) -> Str { value.toText() }"
  , "trait CheckedStep { fn step(self: &Self) -> " <> checked <> " }"
  , "impl CheckedStep for Str { fn step(self: &Self) -> " <> checked <> " { " <> checkedBody <> " } }"
  , "trait HeldStep { fn step(self: &Self) -> " <> held <> " }"
  , "impl HeldStep for Option[Str] { fn step(self: &Self) -> " <> held <> " { " <> heldBody <> " } }"
  ]

stateSequence :: Text -> Text -> [Text]
stateSequence beginBody advanceBody =
  [ "trait Sequence[S, T] {"
  , "  fn begin(self: &Self) -> S"
  , "  fn advance(self: &Self, state: S) -> Option[(S, T)]"
  , "}"
  , "type Steps = { start: Int }"
  , "impl Sequence[Int, Int] for Steps {"
  , "  fn begin(self: &Self) -> Int { print(\"begin\")\n " <> beginBody <> " }"
  , "  fn advance(self: &Self, state: Int) -> Option[(Int, Int)] {"
  , "    print(show(state))"
  , "    " <> advanceBody
  , "  }"
  , "}"
  ]

forSuccessPrograms :: [(String, Text, Text)]
forSuccessPrograms =
  [ ("ranges walk their ends once, empty and single ranges included", program
      [ "fn tag(label: Str, value: Int) -> Int {", "  print(label)", "  value", "}"
      , "fn main() -> Int {"
      , "  var total = 0", "  for i in 0..5 { total = total + i }", "  print(display(total))"
      , "  for i in tag(\"start\", 3)..=tag(\"end\", 5) { print(display(i)) }"
      , "  for i in 5..5 { print(\"never\") }", "  for i in 6..2 { print(\"never\") }"
      , "  for i in 7..=7 { print(\"once \" + display(i)) }"
      , "  return 0", "}" ]
    , "10\nstart\nend\n3\n4\n5\nonce 7\n")
  , ("ranges reach the ends of Int without overflowing", program
      [ "fn main() -> Int {"
      , "  for i in 9223372036854775805..=9223372036854775807 { print(display(i)) }"
      , "  for i in -9223372036854775807-1..-9223372036854775806 { print(display(i)) }"
      , "  return 0", "}" ]
    , "9223372036854775805\n9223372036854775806\n9223372036854775807\n-9223372036854775808\n-9223372036854775807\n")
  , ("labels, break, continue and refutable binders", program
      [ "fn main() -> Int {"
      , "  @outer for row in 0..3 {"
      , "    for column in 0..3 {"
      , "      if column == 1 { continue }", "      if row == 2 { break @outer }"
      , "      print(display(row) + \",\" + display(column))"
      , "    }", "  }"
      , "  for 2 in 0..4 { print(\"two\") }"
      , "  for i in 0..10 {", "    if i == 3 { break }", "    print(display(i))", "  }"
      , "  return 0", "}" ]
    , "0,0\n0,2\n1,0\n1,2\ntwo\n0\n1\n2\n")
  , ("a sequence begins once and advances until None", program $ countdown <>
      [ "fn first(seq: Countdown) -> Str {"
      , "  for word in seq { return word }", "  \"empty\"", "}"
      , "fn main() -> Int {"
      , "  let three = Countdown{from: 3}", "  for word in three { print(word) }"
      , "  let none = Countdown{from: 0}", "  for _ in none { print(\"never\") }"
      , "  print(first(three) + \" \" + first(none))"
      , "  return 0", "}" ]
    , "t3\nt2\nt1\nt3 empty\n")
  , ("a sequence carries the held next state through a skipped binder", program $
      sequenceView "Int" "1" "Str" "\"next\"" <>
      stateSequence "self.start" "if show(state) == \"2\" { Some((select(\"λ\".toBytes()).step(), 0)) } else { None }" <>
      [ "fn main() -> Int {"
      , "  for 9 in Steps{start: 2} { print(\"unreached\") }"
      , "  print(\"done\")"
      , "  0", "}" ]
    , "begin\n2\n\"next\"\ndone\n")
  , ("for over Str, tuples and a sum's payload, and charFromCode", program
      [ "type Pair = Two(Int, Int) | One(Int) | Zero", "", "fn main() -> Int {"
      , "  for c in \"héllo\" { print(display(c)) }", "  for n in (1, 2, 3) { print(display(n * 10)) }", "  for v in Some(5) { print(display(v)) }"
      , "  let none: Option[Int] = None", "  for v in none { print(display(v)) }", "  for p in Two(7, 8) { print(display(p)) }"
      , "  for p in One(4) { print(display(p)) }", "  print(show(charFromCode(97)) + show(charFromCode(55296)) + show(charFromCode(1114112)) + show(charFromCode(-1)) + show(charFromCode(128512)) + show(charFromCode(0)))", "  return 0"
      , "}" ]
    , "h\né\nl\nl\no\n10\n20\n30\n5\n7\n8\n4\nSome('a')NoneNoneNoneSome('😀')Some('\0')\n")
  ]

{-| A failure inside the body reports at its own source. -}
forRefusalPrograms :: [(String, Text)]
forRefusalPrograms =
  [ ("an overflow inside a range body keeps its span", program
      [ "fn main() -> Int {", "  var total = 9223372036854775800"
      , "  for i in 0..10 {", "    print(display(i))", "    total = total + i", "  }"
      , "  return 0", "}" ])
  , ("a malformed advance result fails after the call reports its effects", program $
      sequenceView "Option[(Int, Int)]" "Some((1, 2))" "Option[Int]" "Some(3)" <>
      stateSequence "self.start" "select(\"λ\".toBytes()).step()" <>
      [ "fn main() -> Int {"
      , "  for item in Steps{start: 2} { print(display(item)) }"
      , "  0", "}" ])
  , ("a transfer from begin reaches the caller before any step", program $
      stateSequence "panic(\"stopped\")" "Some((0, 1))" <>
      [ "fn main() -> Int {"
      , "  for item in Steps{start: 2} { print(display(item)) }"
      , "  0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
