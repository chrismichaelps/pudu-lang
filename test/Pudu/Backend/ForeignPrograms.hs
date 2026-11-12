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
  ]

foreignRefusalPrograms :: [(String, Text)]
foreignRefusalPrograms =
  [ ("a library that does not open stops at the call with every name tried", program
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
