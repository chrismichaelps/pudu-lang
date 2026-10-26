{-| @Test.Backend.ConvertPrograms — `convertInteger` and type arguments on
    generic calls, against `callConvertInteger`. -}
module Pudu.Backend.ConvertPrograms (convertSuccessPrograms, convertRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

convertSuccessPrograms :: [(String, Text, Text)]
convertSuccessPrograms =
  [ ("convertInteger at and past every bound, 128-bit kinds and type arguments on generic calls", program
      [ "fn first[T](items: Array[T], fallback: T) -> T {", "  if items.isEmpty() { fallback } else { items[0] }", "}"
      , "", "fn pair[A, B](a: A, b: B) -> (A, B) { (a, b) }", ""
      , "fn byte(value: Int) -> Result[UInt8, Str] {", "  match convertInteger[UInt8](value) {", "    case Some(b) => Ok(b)"
      , "    case None => Err(\"too big: \" + display(value))", "  }", "}"
      , "", "fn twice(value: Int) -> Result[Int, Str] {", "  let b = byte(value)?"
      , "  match convertInteger[Int](b) {", "    case Some(n) => Ok(n * 2)", "    case None => Err(\"lost\")"
      , "  }", "}", ""
      , "fn main() -> Int {", "  print(show(convertInteger[UInt8](255)) + \" \" + show(convertInteger[UInt8](256)) + \" \" + show(convertInteger[UInt8](-1)) + \" \" + show(convertInteger[UInt8](0)))", "  print(show(convertInteger[Int8](-128)) + \" \" + show(convertInteger[Int8](-129)) + \" \" + show(convertInteger[Int8](127)) + \" \" + show(convertInteger[Int8](128)))"
      , "  print(show(convertInteger[Int16](32767)) + \" \" + show(convertInteger[UInt16](65536)) + \" \" + show(convertInteger[Int32](-2147483648)) + \" \" + show(convertInteger[UInt32](4294967295)))", "  let big: UInt64 = 18446744073709551615u64", "  print(show(convertInteger[Int](big)) + \" \" + show(convertInteger[UInt64](-1)) + \" \" + show(convertInteger[Int](9223372036854775807u64)) + \" \" + show(convertInteger[Int](9223372036854775808u64)))"
      , "  let wide: Int128 = 170141183460469231731687303715884105727i128", "  print(show(convertInteger[Int](wide)) + \" \" + show(convertInteger[UInt128](wide)) + \" \" + show(convertInteger[Int128](-5)) + \" \" + show(convertInteger[UInt128](-5)))", "  let small: Int128 = -9223372036854775808i128"
      , "  print(show(convertInteger[Int](small)) + \" \" + show(convertInteger[Int](small - 1i128)) + \" \" + show(convertInteger[UInt8](200i128)))", "  let top: UInt128 = 340282366920938463463374607431768211455u128", "  print(show(convertInteger[Int128](top)) + \" \" + show(convertInteger[UInt64](top)) + \" \" + show(convertInteger[UInt128](big)))"
      , "  print(show(twice(21)) + \" \" + show(twice(300)))", "  if let Some(b) = convertInteger[UInt16](1000) { print(display(b + 1u16)) }", "  print(display(first[Int]([], 7)) + \" \" + display(first[Str]([\"a\"], \"z\")) + \" \" + show(pair[Int, Bool](1, true)))"
      , "  return 0", "}" ]
    , "Some(255) None None Some(0)\nSome(-128) None Some(127) None\nSome(32767) None Some(-2147483648) Some(4294967295)\nNone None Some(9223372036854775807) None\nNone Some(170141183460469231731687303715884105727) Some(-5) None\nSome(-9223372036854775808) None Some(200)\nNone None Some(18446744073709551615)\nOk(42) Err(\"too big: 300\")\n1001\n7 a (1, true)\n")
  ]

convertRefusalPrograms :: [(String, Text)]
convertRefusalPrograms =
  [ ("an overflow on a converted value reports at the operation", program
      [ "fn main() -> Int {", "  match convertInteger[UInt8](255) {", "    case Some(b) => {"
      , "      print(display(b))", "      print(display(b + 1u8))", "    }"
      , "    case None => print(\"none\")", "  }", "  return 0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
