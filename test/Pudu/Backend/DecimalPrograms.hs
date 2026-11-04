{-| @Test.Backend.DecimalPrograms — Decimal values: exact arithmetic and
    comparison across scales, division that is exact or fails, the seven
    rounding modes, parsing, conversions and collections. -}
module Pudu.Backend.DecimalPrograms (decimalSuccessPrograms, decimalLeakPrograms, decimalRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

decimalSuccessPrograms :: [(String, Text, Text)]
decimalSuccessPrograms =
  [ ("Std.Decimal primitives, division, parsing and conversion", program
      [ "import Std.Decimal"
      , ""
      , "fn main() -> Int {"
      , "  let a = 1.50d"
      , "  let b = -0.25d"
      , "  print(display(a + b) + \" \" + display(a * b) + \" \" + display(a - b) + \" \" + display(a / b))"
      , "  print(show(a) + \" \" + show([a, b]) + display(a == 1.5d) + display(b < a))"
      , "  print(display(Decimal.round(2.5d, 0, Decimal.HalfEven)) + \" \" + display(Decimal.round(-2.1d, 0, Decimal.Floor)))"
      , "  print(show(Decimal.divide(1d, 3d, 5, Decimal.HalfUp)) + show(Decimal.parse(\"1_000.5e-2\")) + show(\"12.30\".toDecimal()))"
      , "  print(display(Decimal.toFloat64(0.1d)) + \" \" + show(Decimal.toInt(4.000d)) + show(Decimal.toInt(4.5d)) + \" \" + display(Decimal.scale(4.000d)))"
      , "  0"
      , "}" ]
    , "1.25 -0.3750 1.75 -6\n1.50 [1.50, -0.25]truetrue\n2 -3\nSome(0.33333)Some(10.005)Some(12.30)\n0.1 Some(4)None 3\n")
  , ("every operator, seven rounding modes, parsing edges, collections and conversions", program
      [ "import Std.Decimal"
      , ""
      , "type Line = { item: Str, price: Decimal }"
      , "type Amount = Known(Decimal) | Unknown"
      , ""
      , "fn total(lines: Array[Line]) -> Decimal {"
      , "  var sum = 0d"
      , "  for line in lines { sum = sum + line.price }"
      , "  sum"
      , "}"
      , ""
      , "fn describe(value: Decimal) -> Str {"
      , "  if value == 0d { \"zero\" } else if value == 1.50d { \"one and a half\" } else if value < 0d { \"negative\" } else { \"other\" }"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  let a = 123456789012345678901234567890.123456789d"
      , "  let b = -0.000000001d"
      , "  print(display(a + b) + \" \" + display(a - b) + \" \" + display(a * b))"
      , "  print(display(1d / 8d) + \" \" + display(-3d / 0.04d) + \" \" + display(0d / 5d) + \" \" + display(2.50d * 4d))"
      , "  print(display(1.0d == 1.000d) + display(1.5d < 1.51d) + display(-0.0d == 0d) + display(a > b) + display(b >= b))"
      , "  let modes = [Decimal.Up, Decimal.Down, Decimal.Ceiling, Decimal.Floor, Decimal.HalfUp, Decimal.HalfDown, Decimal.HalfEven]"
      , "  for mode in modes {"
      , "    print(display(Decimal.round(2.5d, 0, mode)) + \" \" + display(Decimal.round(-2.5d, 0, mode)) + \" \""
      , "      + display(Decimal.round(2.45d, 1, mode)) + \" \" + display(Decimal.round(-7.123d, 2, mode)) + \" \""
      , "      + show(Decimal.divide(2d, 3d, 4, mode)) + \" \" + show(Decimal.divide(-1d, 6d, 2, mode)))"
      , "  }"
      , "  print(display(Decimal.round(1.5d, 3, Decimal.Up)) + \" \" + display(Decimal.rescale(9.876d, 1)) + \" \" + display(Decimal.round(99.95d, -1, Decimal.HalfUp)))"
      , "  print(show(Decimal.divide(1d, 0d, 2, Decimal.HalfEven)) + show(Decimal.parse(\"  -12.5e3 \")) + show(Decimal.parse(\"1__0.0_1\")) + show(Decimal.parse(\"e5\")) + show(Decimal.parse(\".5\")) + show(Decimal.parse(\"5.\")) + show(Decimal.parse(\"1e6145\")))"
      , "  print(show(\"3.25\".toDecimal()) + show(\"3 .25\".toDecimal()) + show(\"1_0\".toDecimal()) + show(\"-0.001E-2\".toDecimal()))"
      , "  print(display(Decimal.toFloat64(0.1d)) + \" \" + display(Decimal.toFloat64(-123456789.987654321d)) + \" \" + display(Decimal.toFloat64(Decimal.round(1d, 400, Decimal.Up) / 1000d)))"
      , "  print(show(Decimal.toInt(-42.000d)) + show(Decimal.toInt(4.01d)) + \" \" + display(Decimal.scale(1.2300d)) + \" \" + display(Decimal.fromInt(-77)) + \" \" + display(Decimal.scale(Decimal.fromInt(5))))"
      , "  let lines = [Line{item: \"a\", price: 19.99d}, Line{item: \"b\", price: 0.01d}, Line{item: \"c\", price: -5d}]"
      , "  print(show(lines) + \" \" + display(total(lines)) + \" \" + show(Known(2.0d)) + show(Unknown))"
      , "  print(describe(0.00d) + \" \" + describe(1.5d) + \" \" + describe(-2d) + \" \" + describe(3d))"
      , "  let prices = mapOf([(\"x\", 1.10d), (\"y\", 1.1d)])"
      , "  print(show(prices) + \" \" + show(setOf([1.10d, 1.1d, 0.5d, -2d])) + \" \" + show(-a) + \" \" + display(Decimal.abs(-1.5d)) + \" \" + display(Decimal.max(1.5d, 1.50d)))"
      , "  0"
      , "}" ]
    , "123456789012345678901234567890.123456788 123456789012345678901234567890.123456790 -123456789012345678901.234567890123456789\n0.125 -75 0 10.00\ntruetruetruetruetrue\n3 -3 2.5 -7.13 Some(0.6667) Some(-0.17)\n2 -2 2.4 -7.12 Some(0.6666) Some(-0.16)\n3 -2 2.5 -7.12 Some(0.6667) Some(-0.16)\n2 -3 2.4 -7.13 Some(0.6666) Some(-0.17)\n3 -3 2.5 -7.12 Some(0.6667) Some(-0.17)\n2 -2 2.4 -7.12 Some(0.6667) Some(-0.17)\n2 -2 2.4 -7.12 Some(0.6667) Some(-0.17)\n1.500 9.9 100\nNoneSome(-12500)Some(10.01)NoneSome(0.5)Some(5)None\nSome(3.25)NoneNoneSome(-0.00001)\n0.1 -1.2345678998765433e8 1.0e-3\nSome(-42)None 4 -77 0\n[Line{item: \"a\", price: 19.99}, Line{item: \"b\", price: 0.01}, Line{item: \"c\", price: -5}] 15.00 Known(2.0)Unknown\nzero one and a half negative other\n{\"x\": 1.10, \"y\": 1.1} #{-2, 0.5, 1.10} -123456789012345678901234567890.123456789 1.5 1.50\n")
  , ("exact sums, primitives and collections without the library", program
      [ "type Line = { item: Str, price: Decimal }"
      , ""
      , "fn main() -> Int {"
      , "  var total = 0d"
      , "  var index = 0"
      , "  while index < 200 {"
      , "    total = total + decimalRound(decimalFromInt(index) / 8d, 2, index % 7)"
      , "    index = index + 1"
      , "  }"
      , "  print(display(total) + \" \" + display(decimalScale(total)) + \" \" + show(decimalToInt(total)))"
      , "  var lines = [Line{item: \"a\", price: 0d}]"
      , "  for step in 0..50 {"
      , "    let parsed = decimalOf(display(step) + \".25\")"
      , "    if let Some(value) = parsed { lines = lines.push(Line{item: \"x\", price: value * 2d}) }"
      , "  }"
      , "  print(display(lines.length()) + \" \" + show(lines[50]) + \" \" + show(decimalDivide(total, 3d, 5, 6)) + \" \" + show(decimalDivide(total, 0d, 5, 6)))"
      , "  let keyed = mapOf([(\"a\", 1.10d), (\"b\", -0.5d)])"
      , "  print(show(keyed) + \" \" + show(setOf([2d, 2.00d, 0.1d])) + \" \" + display(decimalToFloat(total)) + \" \" + show(\"9.75\".toDecimal()))"
      , "  0"
      , "}" ]
    , "2487.49 2 None\n51 Line{item: \"x\", price: 98.50} Some(829.16333) None\n{\"a\": 1.10, \"b\": -0.5} #{0.1, 2} 2487.49 Some(9.75)\n")
  , ("Decimal primitive values retain signatures, identity and owned results", program
      [ "fn apply[T, U](f: fn(T) -> U, value: T) -> U { f(value) }"
      , "fn parser() -> fn(Str) -> Option[Decimal] {"
      , "  let parse = decimalOf"
      , "  |text| parse(text)"
      , "}"
      , "fn main() -> Int {"
      , "  let parse = decimalOf"
      , "  let fromInt = decimalFromInt"
      , "  let scale = decimalScale"
      , "  let toInt = decimalToInt"
      , "  let toFloat = decimalToFloat"
      , "  let divide = decimalDivide"
      , "  let round = decimalRound"
      , "  print(show(parse) + \" \" + show(fromInt) + \" \" + show(scale) + \" \" + show(toInt))"
      , "  print(show(toFloat) + \" \" + show(divide) + \" \" + show(round))"
      , "  print(display(parse == decimalOf) + \" \" + display(toInt == decimalToInt) + \" \" + display(fromInt == decimalFromInt))"
      , "  print(show(parse(\"  1_234.500e-1  \")) + show(parse(\"not a decimal\")) + show(parser()(\"-0.125\")))"
      , "  print(display(apply(fromInt, -42)) + \" \" + display(apply(scale, 1.2300d)) + \" \" + show(apply(toInt, -42.00d)) + show(toInt(1.5d)))"
      , "  print(display(toFloat(0.125d)) + \" \" + show(divide(1d, 3d, 3, 6)) + show(divide(1d, 0d, 3, 6)) + \" \" + display(round(-2.5d, 0, 6)))"
      , "  let converters = [decimalOf, parse]"
      , "  print(show(converters[1](\"9.00\")))"
      , "  var total = 0d"
      , "  for index in 0..100 {"
      , "    if let Some(value) = parse(display(index) + \".25\") { total = total + value }"
      , "  }"
      , "  print(display(total))"
      , "  let decimalOf: fn(Str) -> Option[Decimal] = |text| Some(7d)"
      , "  print(show(decimalOf(\"local\")) + \" \" + show(parse(\"8\")))"
      , "  0"
      , "}" ]
    , "<builtin decimalOf> <builtin decimalFromInt> <builtin decimalScale> <builtin decimalToInt>\n<builtin decimalToFloat> <builtin decimalDivide> <builtin decimalRound>\ntrue true true\nSome(123.4500)NoneSome(-0.125)\n-42 4 Some(-42)None\n0.125 Some(0.333)None -2\nSome(9.00)\n4975.00\nSome(7) Some(8)\n")
  , ("Decimal callable arguments run once in order and transfers stop invocation", program
      [ "fn number(label: Str, value: Decimal) -> Decimal { print(label)\n value }"
      , "fn integer(label: Str, value: Int) -> Int { print(label)\n value }"
      , "fn main() -> Int {"
      , "  let divide = decimalDivide"
      , "  print(show(divide(number(\"left\", 1d), number(\"right\", 8d), integer(\"scale\", 3), integer(\"mode\", 6))))"
      , "  let round = decimalRound"
      , "  round(number(\"before transfer\", 1d), { return 0 }, integer(\"unreachable\", 6))"
      , "  1"
      , "}" ]
    , "left\nright\nscale\nmode\nSome(0.125)\nbefore transfer\n")
  ]

{-| The successes that need no library, which counted allocation compiles on
    its own. -}
decimalLeakPrograms :: [(String, Text, Text)]
decimalLeakPrograms = drop 2 decimalSuccessPrograms

decimalRefusalPrograms :: [(String, Text)]
decimalRefusalPrograms =
  [ ("a Decimal builtin entry renders its tag", program
      [ "fn main() -> fn(Str) -> Option[Decimal] { decimalOf }" ])
  , ("a Decimal callable argument failure keeps its source and stops later arguments", program
      [ "fn main() -> Int {"
      , "  let divide = decimalDivide"
      , "  print(show(divide({ print(\"left\")\n 1d }, { print(\"failure\")\n 1d / 0d }, { print(\"unreachable\")\n 2 }, 6)))"
      , "  0"
      , "}" ])
  , ("ordering Decimal builtin values reports their runtime kind", program
      [ "fn main() -> Int {"
      , "  let left = decimalOf"
      , "  let right = decimalOf"
      , "  print(display(left < right))"
      , "  0"
      , "}" ])
  , ("decimal division by zero after an exact quotient", program
      [ "fn main() -> Int {"
      , "  let zero = 0.00d"
      , "  print(display(1.5d / 0.5d))"
      , "  print(display(1.5d / zero))"
      , "  0"
      , "}" ])
  , ("a quotient with no terminating expansion fails with its help", program
      [ "fn main() -> Int {"
      , "  print(display(1d / 4d))"
      , "  print(display(10d / 3d))"
      , "  0"
      , "}" ])
  , ("an entry Decimal is printed at its scale", program
      [ "fn main() -> Decimal {"
      , "  let held = -12.340d"
      , "  held * 2d"
      , "}" ])
  , ("a long exact sum then a non-terminating quotient", program
      [ "fn main() -> Int {"
      , "  var total = 0d"
      , "  var index = 0"
      , "  while index < 500 {"
      , "    total = total + 0.001d * 3d"
      , "    index = index + 1"
      , "  }"
      , "  print(display(total))"
      , "  total = total / 7d"
      , "  0"
      , "}" ])
  ]

program :: [Text] -> Text
program lines' = Text.unlines (["module Main", ""] <> lines')
