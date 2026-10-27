{-| @Test.Backend.ReferencePrograms — shared carriers and preserved transfers. -}
module Pudu.Backend.ReferencePrograms (referenceSuccessPrograms, referenceRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

referenceSuccessPrograms :: [(String, Text, Text)]
referenceSuccessPrograms =
  [ ("a borrowed print Result keeps the printed output", program
      [ "fn main() -> Int {"
      , "  let held = &print(\"x\")"
      , "  print(show(*held))"
      , "  0"
      , "}" ], "x\nOk(())\n")
  , ("shared parameters and results carry scalar and record values", program
      [ "type Point = { x: Int }"
      , "fn read(point: &Point) -> Int { point.x }"
      , "fn forward(value: &Int) -> &Int { value }"
      , "fn text(value: &Str) -> Str { *value }"
      , "fn main() -> Int {"
      , "  let point = Point{x: 9}", "  let number = 7"
      , "  print(display(read(&point)))", "  print(display(*forward(&number)))"
      , "  print(text(&\"hello\"))", "  return 0", "}" ]
    , "9\n7\nhello\n")
  , ("shared tuple and sum reads retain owned payloads", program
      [ "type Box = { label: Str }", "const BOX = Box{label: \"held\"}"
      , "fn part(pair: &(Int, Str)) -> Str { pair[1] }"
      , "fn choose(value: &Option[Box]) -> Str {"
      , "  match value { case Some(box) => box.label case None => \"empty\" }", "}"
      , "fn main() -> Int {"
      , "  let pair = (3, \"tuple\")", "  let value = Some(BOX)"
      , "  print(part(&pair))", "  print(choose(&value))"
      , "  let absent: Option[Box] = None", "  print(choose(&absent))"
      , "  print(show(&BOX))", "  return 0", "}" ]
    , "tuple\nheld\nempty\nBox{label: \"held\"}\n")
  , ("borrowing evaluates operands once and preserves Never transfers", program
      [ "fn add(left: &Int, right: &Int) -> Int { *left + *right }"
      , "fn early() -> Int {"
      , "  let held = &{ print(\"early\")", "    return 7 }", "  *held", "}"
      , "fn main() -> Int {"
      , "  print(display(add(&{ print(\"left\")", "    2 }, &{ print(\"right\")", "    3 })))"
      , "  print(display(early()))", "  return 0", "}" ]
    , "left\nright\n5\nearly\n7\n")
  , ("shared carriers retain primitive widths and ordinary methods", program
      [ "fn wide(value: &UInt128) -> UInt128 { *value }"
      , "fn negate(value: &Float32) -> Float32 { -*value }"
      , "fn size(value: &Str) -> Int { value.length() }"
      , "fn flag(value: &Bool) -> Bool { *value }"
      , "fn unit(value: &()) -> Str { show(value) }"
      , "fn main() -> Int {"
      , "  print(display(wide(&340282366920938463463374607431768211455u128)))"
      , "  print(display(negate(&0.1f32)))", "  print(display(size(&\"aλ🦌\")))"
      , "  print(display(flag(&true)) + \" \" + unit(&()))", "  return 0", "}" ]
    , "340282366920938463463374607431768211455\n-0.10000000149011612\n3\ntrue ()\n")
  , ("a borrow keeps the value its variable held when it was taken", program
      [ "fn main() -> Int {"
      , "  var count = 1", "  var label = \"before\""
      , "  let held = &count", "  let text = &label"
      , "  count = 2", "  label = \"after\""
      , "  print(display(*held) + \" \" + display(count) + \" \" + *text + \" \" + label)", "  return 0", "}" ]
    , "1 2 before after\n")
  ]

referenceRefusalPrograms :: [(String, Text)]
referenceRefusalPrograms =
  [ ("a borrowed operand retains its callee overflow span", program
      [ "fn increment(value: &Int) -> Int { *value + 1 }"
      , "fn main() -> Int {", "  print(\"before\")"
      , "  increment(&9223372036854775807)", "}" ])
  , ("dereference preserves dynamic unary refusal provenance", program
      [ "fn wrong(value: &Bool) -> Bool { -*value }"
      , "fn main() -> Int {", "  print(\"before\")"
      , "  print(display(wrong(&false)))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
