{-| @Test.Backend.StoppingBuiltinPrograms — panic and untyped convertInteger,
    called directly and through values, stop exactly where the interpreter
    does. -}
module Pudu.Backend.StoppingBuiltinPrograms
  ( stoppingBuiltinSuccessPrograms, stoppingBuiltinRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text

stoppingBuiltinSuccessPrograms :: [(String, Text, Text, Text)]
stoppingBuiltinSuccessPrograms =
  [ ("stopping builtins render and compare as values", program
      [ "type Guard = { fail: fn(Str) -> Never }"
      , "fn chooser() -> fn(Str) -> Never { panic }"
      , "fn main() -> Int {"
      , "  print(show(panic))"
      , "  print(show(convertInteger))"
      , "  print(display(panic == panic))"
      , "  print(display(convertInteger == convertInteger))"
      , "  let stop: fn(Str) -> Never = panic"
      , "  print(show(Guard{fail: stop}))"
      , "  print(display(chooser() == stop))"
      , "  let convert: fn(Int) -> Option[UInt8] = convertInteger"
      , "  print(display(convert == convertInteger))"
      , "  let narrow: fn(Int) -> Option[UInt8] = |value| convertInteger[UInt8](value)"
      , "  print(show(narrow(7)))"
      , "  0"
      , "}" ]
    , "<builtin panic>\n<builtin convertInteger>\ntrue\ntrue\nGuard{fail: <builtin panic>}\ntrue\ntrue\nSome(7)\n", "")
  ]

stoppingBuiltinRefusalPrograms :: [(String, Text)]
stoppingBuiltinRefusalPrograms =
  [ ("panic after partial output in a generic function and a loop", program
      [ "fn check[T](value: T, ok: Bool) -> T {"
      , "  if !ok { panic(\"bad \" + show(value)) }"
      , "  value"
      , "}"
      , "fn main() -> Int {"
      , "  printPart(\"partial\")"
      , "  print(display(check(3, true)))"
      , "  for index in 0..5 {"
      , "    if index == 2 { check(\"x\", false) }"
      , "    print(display(index))"
      , "  }"
      , "  0"
      , "}" ])
  , ("panic keeps a multi-line message", program
      [ "fn main() -> Int {"
      , "  panic(\"line one\\nline two\")"
      , "}" ])
  , ("an empty panic message reads as the placeholder", program
      [ "fn main() -> Int {"
      , "  panic(\"\")"
      , "}" ])
  , ("convertInteger without a type refuses after its argument", program
      [ "fn main() -> Int {"
      , "  print(display(convertInteger(5)))"
      , "  0"
      , "}" ])
  , ("panic through a captured record field names the field call", program
      [ "type Guard = { fail: fn(Str) -> Never }"
      , "fn main() -> Int {"
      , "  let guard = Guard{fail: panic}"
      , "  print(show(guard))"
      , "  let later = |text: Str| guard.fail(text + \"!\")"
      , "  later({ print(\"argument\")"
      , " \"stop\" })"
      , "  0"
      , "}" ])
  , ("convertInteger through a value refuses after its argument", program
      [ "fn main() -> Int {"
      , "  let convert: fn(Int) -> Option[UInt8] = convertInteger"
      , "  print(show(convert))"
      , "  print(show(convert({ print(\"argument\")"
      , " 300 })))"
      , "  0"
      , "}" ])
  , ("panic with a non-text argument refuses after the argument", program
      [ "fn main() -> Int {"
      , "  print(\"a\")"
      , "  panic({ print(\"b\")"
      , " 5 })"
      , "}" ])
  , ("panic with no argument refuses with help", program
      [ "fn main() -> Int {"
      , "  panic()"
      , "}" ])
  , ("panic through an annotated binding names the call", program
      [ "fn main() -> Int {"
      , "  print(show(convertInteger))"
      , "  print(display(convertInteger == convertInteger))"
      , "  print(show(panic))"
      , "  let stop: fn(Str) -> Never = panic"
      , "  print(\"before\")"
      , "  stop(\"boom\")"
      , "  0"
      , "}" ])
  , ("panic returned from a function names the call through it", program
      [ "fn chooser() -> fn(Str) -> Never { panic }"
      , "fn main() -> Int {"
      , "  print(show(chooser()))"
      , "  chooser()(\"chosen\")"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
