{-| @Test.Backend.ForeignPrograms — foreign calls through typed native call
    sites against the interpreter's bridge: the C library reached through `c`,
    and the E7015 stops for a library that does not open and a symbol it does
    not export. -}
module Pudu.Backend.ForeignPrograms (foreignSuccessPrograms, foreignRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

foreignSuccessPrograms :: [(String, Text)]
foreignSuccessPrograms =
  [ ("the C library answers integers, floats and predicates through c", program
      [ "foreign \"c\" version \"1\" {"
      , "  fn absolute symbol \"abs\" (value: Int32) -> Int32"
      , "  fn labs(value: Int64) -> Int64"
      , "  fn pow(base: Float64, exponent: Float64) -> Float64"
      , "  fn sqrt(value: Float64) -> Float64"
      , "  fn isalpha(code: Int32) -> Int32"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe {"
      , "    print(display(absolute(-42i32)) + \" \" + display(labs(-9000000000i64)) + \" \" + display(pow(2.0, 0.5)) + \" \" + display(sqrt(2.0)))"
      , "    print(display(isalpha(65i32) != 0i32) + \" \" + display(isalpha(49i32)) + \" \" + display(absolute(absolute(-7i32))))"
      , "  }"
      , "  0"
      , "}" ])
  , ("text and lent bytes cross to the C library and text comes back", program
      [ "foreign \"c\" {"
      , "  fn strlen(text: Str) -> Int64"
      , "  fn strchr(text: Str, code: Int32) -> Str"
      , "  fn strnlen(data: Bytes, most: Int64) -> Int64"
      , "  fn memcmp(left: Bytes, right: Bytes, length: Int64) -> Int32"
      , "  fn strerror(code: Int32) -> Str"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe {"
      , "    print(display(strlen(\"héllo\")) + \" \" + display(strlen(\"\")) + \" \" + strchr(\"pudu-lang\", 45i32) + \" \" + display(strerror(2i32).length() > 0))"
      , "    let data = bytesOf([104u8, 105u8, 0u8, 9u8])"
      , "    print(display(strnlen(data, 4i64)) + \" \" + display(strnlen(bytesOf([]), 0i64)) + \" \" + display(memcmp(data, data, 4i64)) + \" \" + display(memcmp(bytesOf([1u8]), bytesOf([2u8]), 1i64) < 0i32))"
      , "  }"
      , "  0"
      , "}" ])
  , ("records come back by value from the C library", program
      [ "type Division = { quot: Int32, rem: Int32 }"
      , "type LongDivision = { quot: Int64, rem: Int64 }"
      , "foreign \"c\" {"
      , "  fn div(numerator: Int32, denominator: Int32) -> Division"
      , "  fn ldiv(numerator: Int64, denominator: Int64) -> LongDivision"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe {"
      , "    let parts = div(17i32, 5i32)"
      , "    print(show(parts) + \" \" + show(div(-17i32, 5i32)) + \" \" + display(parts.quot * 5i32 + parts.rem))"
      , "    print(show(ldiv(9000000000i64, 7i64)))"
      , "  }"
      , "  0"
      , "}" ])
  ]

foreignRefusalPrograms :: [(String, Text)]
foreignRefusalPrograms =
  [ ("text holding a nought stops before the call", program
      [ "foreign \"c\" {"
      , "  fn strlen(text: Str) -> Int64"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(display(strlen(\"a\\u{0}b\"))) }"
      , "  0"
      , "}" ])
  , ("a text result the library does not give stops after the call", program
      [ "foreign \"c\" {"
      , "  fn getenv(name: Str) -> Str"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(getenv(\"PUDU_NATIVE_SURELY_UNSET_VARIABLE\")) }"
      , "  0"
      , "}" ])
  , ("a library that does not open stops at the call with every name tried", program
      [ "foreign \"puduabsentlibrary\" version \"3\" {"
      , "  fn nothing(value: Int32) -> Int32"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(display(nothing(1i32))) }"
      , "  0"
      , "}" ])
  , ("a symbol the library does not export stops at the call", program
      [ "foreign \"c\" {"
      , "  fn absent symbol \"pudu_no_such_symbol_here\" (value: Int32) -> Int32"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(display(absent(1i32))) }"
      , "  0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
