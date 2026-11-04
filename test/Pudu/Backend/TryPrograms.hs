{-| @Test.Backend.TryPrograms — `?` on Result and Option. -}
module Pudu.Backend.TryPrograms (trySuccessPrograms, tryRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

parse :: [Text]
parse =
  [ "fn parse(text: Str) -> Result[Int, Str] {"
  , "  if text == \"bad\" { return Err(\"cannot read \" + text) }"
  , "  Ok(text.length())"
  , "}" ]

trySuccessPrograms :: [(String, Text, Text)]
trySuccessPrograms =
  [ ("? passes success on and returns failure at the function's own type", program $ parse <>
      [ "fn twice(text: Str) -> Result[Str, Str] {"
      , "  let first = parse(text)?", "  let second = parse(text + text)?"
      , "  Ok(display(first + second))", "}"
      , "fn main() -> Int {"
      , "  print(show(twice(\"ab\")))", "  print(show(twice(\"bad\")))", "  return 0", "}" ]
    , "Ok(\"6\")\nErr(\"cannot read bad\")\n")
  , ("? on Option stops before what follows it", program
      [ "fn pick(value: Option[Int]) -> Option[Bool] {"
      , "  print(\"before\")", "  let held = value?", "  print(\"after\")", "  Some(held > 2)", "}"
      , "fn main() -> Int {"
      , "  print(show(pick(Some(5))))", "  print(show(pick(None)))", "  return 0", "}" ]
    , "before\nafter\nSome(true)\nbefore\nNone\n")
  , ("? inside loops, operators and arguments", program $ parse <>
      [ "fn total(items: Option[Int], extra: Option[Int]) -> Option[Int] {"
      , "  var sum = 0", "  var count = 0"
      , "  while count < 3 {", "    sum = sum + items? + extra?", "    count = count + 1", "  }"
      , "  Some(sum)", "}"
      , "fn tag(label: Str) -> Str {", "  print(label)", "  label", "}"
      , "fn joined(left: Str, right: Str) -> Result[Str, Str] {"
      , "  Ok(tag(display(parse(left)?)) + tag(display(parse(right)?)))", "}"
      , "fn main() -> Int {"
      , "  print(show(total(Some(1), Some(2))) + \" \" + show(total(Some(1), None)))"
      , "  print(show(joined(\"ab\", \"c\")))", "  print(show(joined(\"a\", \"bad\")))"
      , "  return 0", "}" ]
    , "Some(9) None\n2\n1\nOk(\"21\")\n1\nErr(\"cannot read bad\")\n")
  , ("an entry returning Result renders the failure ? returned", program $ parse <>
      [ "fn main() -> Result[Int, Str] {"
      , "  let n = parse(\"xyz\")?", "  print(display(n))"
      , "  let m = parse(\"bad\")?", "  print(\"never\")", "  Ok(m)", "}" ]
    , "3\nErr(\"cannot read bad\")\n")
  , ("an entry returning Option renders None", program
      [ "fn main() -> Option[Int] {", "  let first: Option[Int] = Some(2)"
      , "  let missing: Option[Int] = None", "  let a = first?", "  print(display(a))"
      , "  let b = missing?", "  Some(a + b)", "}" ]
    , "2\nNone\n")
  ]

{-| A failure after `?` passed reports at its own source. -}
tryRefusalPrograms :: [(String, Text)]
tryRefusalPrograms =
  [ ("an overflow after ? keeps its span", program $ parse <>
      [ "fn grow(text: Str) -> Result[Int, Str] {"
      , "  let n = parse(text)?", "  Ok(n + 9223372036854775807)", "}"
      , "fn main() -> Int {", "  print(show(grow(\"bad\")))"
      , "  print(show(grow(\"a\")))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
