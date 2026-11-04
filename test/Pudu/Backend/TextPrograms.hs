{-| @Test.Backend.TextPrograms — owned Str source programs with independent answers. -}
module Pudu.Backend.TextPrograms (textSuccessPrograms, textRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

textSuccessPrograms :: [(String, Text, Text)]
textSuccessPrograms =
  [ ("text literals keep their bytes", program
      [ "fn main() -> Int {"
      , "  let empty = \"\""
      , "  print(empty)"
      , "  print(\"tab\\there \\\"quoted\\\" back\\\\slash\")"
      , "  print(\"h\\u{e9}llo \\u{2713} \\u{1d11e}\")"
      , "  print(\"nul[\\0]\")"
      , "  return 0"
      , "}" ]
    , "\ntab\there \"quoted\" back\\slash\nh\233llo \10003 \119070\nnul[\0]\n")
  , ("concatenation builds and reuses text", program
      [ "fn main() -> Int {"
      , "  var s = \"ab\""
      , "  s = s + s"
      , "  s = s + \"\" + s"
      , "  print(s)"
      , "  var built = \"\""
      , "  var index = 0"
      , "  while index < 5 {"
      , "    built = built + display(index)"
      , "    index = index + 1"
      , "  }"
      , "  print(built)"
      , "  let joined = \"x\" + (\"y\" + \"z\")"
      , "  print(joined)"
      , "  return 0"
      , "}" ]
    , "abababab\n01234\nxyz\n")
  , ("comparisons follow byte order", program
      [ "fn main() -> Int {"
      , "  print(display(\"a\" < \"b\"))", "  print(display(\"ab\" < \"abc\"))", "  print(display(\"\" < \"a\"))"
      , "  print(display(\"\\u{e9}\" > \"z\"))", "  print(display(\"abc\" == \"ab\" + \"c\"))", "  print(display(\"a\" != \"a\"))"
      , "  print(display(\"b\" >= \"b\"))", "  print(display(\"B\" <= \"a\"))", "  print(display(\"a\\0\" > \"a\"))"
      , "  return 0"
      , "}" ]
    , lines' ["true", "true", "true", "true", "true", "false", "true", "true", "true"])
  , ("display and show render every native value", program
      [ "fn main() -> Int {"
      , "  let negative: Int8 = -128"
      , "  let large: UInt64 = 18446744073709551615"
      , "  let wide: Int128 = -170141183460469231731687303715884105728"
      , "  let parts = display(-42) + \" \" + display(negative) + \" \" + display(large) + \" \" + display(wide)"
      , "  print(parts)"
      , "  print(display(0.1) + \" \" + display(0.1f32) + \" \" + display(true) + \" \" + display(()))"
      , "  print(show(7) + show(false) + show(1.5) + show(()))"
      , "  print(show(\"a\\\"b\\\\c\\td\\ne\\r\"))"
      , "  print(display(\"plain\"))"
      , "  return 0"
      , "}" ]
    , lines' [ "-42 -128 18446744073709551615 -170141183460469231731687303715884105728"
             , "0.1 " <> show (0.10000000149011612 :: Double) <> " true ()"
             , "7false1.5()"
             , "\"a\\\"b\\\\c\\td\\ne\r\""
             , "plain" ])
  , ("interpolation renders through display", program
      [ "fn main() -> Int {"
      , "  let name = \"Pudu\""
      , "  let count = 3"
      , "  print(\"{name} has {count} parts, {1.5} wide, {true}, {()} and {name + \"!\"}\")"
      , "  print(\"{display(2)}x\")"
      , "  return 0"
      , "}" ]
    , "Pudu has 3 parts, 1.5 wide, true, () and Pudu!\n2x\n")
  , ("text crosses calls branches loops and recursion", program
      [ "fn greet(name: Str) -> Str { \"hi \" + name }"
      , "fn build(n: Int, acc: Str) -> Str {"
      , "  if n == 0 { return acc }"
      , "  return build(n - 1, acc + display(n))"
      , "}"
      , "fn first(a: Str, b: Str) -> Str { a }"
      , "fn main() -> Int {"
      , "  print(greet(\"there\"))"
      , "  print(build(4, \">\"))"
      , "  var s = \"old\""
      , "  print(first(s, { s = \"new\""
      , "    s }))"
      , "  print(s)"
      , "  let picked = if s == \"new\" { greet(s) } else { \"no\" }"
      , "  print(picked)"
      , "  let found = loop { break s + s }"
      , "  print(found)"
      , "  greet(\"discarded\")"
      , "  return 0"
      , "}" ]
    , "hi there\n>4321\nold\nnew\nhi new\nnewnew\n")
  , ("deep recursion releases text on the way back", program
      [ "fn depth(n: Int) -> Str {"
      , "  if n == 0 { return \"bottom \" + display(n) }"
      , "  let below = depth(n - 1)"
      , "  return below"
      , "}"
      , "fn main() -> Int {"
      , "  print(depth(4000))"
      , "  return 0"
      , "}" ]
    , "bottom 0\n")
  , ("a module display returning Str is the program's own", program
      [ "fn display(value: Int) -> Str { \"mine\" }"
      , "fn main() -> Int {"
      , "  print(display(5))"
      , "  return 0"
      , "}" ]
    , "mine\n")
  , ("Str entry results render quoted", program
      [ "fn main() -> Str { \"a\\\"b\\\\c\\td\\ne\" }" ]
    , "\"a\\\"b\\\\c\\td\\ne\"\n")
  , ("empty Str entry result", program
      [ "fn main() -> Str { \"\" }" ]
    , "\"\"\n")
  ]

{-| Held to the interpreter's rendered diagnostics rather than an answer. -}
textRefusalPrograms :: [(String, Text)]
textRefusalPrograms =
  [ (label <> " refuses at run time", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let x = " <> expression, "  print(display(x))", "  return 0", "}" ])
  | (label, expression) <-
      [ ("text subtraction", "\"a\" - \"b\""), ("text multiplication", "\"a\" * \"b\"")
      , ("text remainder", "\"a\" % \"b\""), ("text bit and", "\"a\" & \"b\"")
      , ("text wrapping add", "\"a\" &+ \"b\""), ("text negation", "-\"a\"")
      , ("text complement", "~\"a\""), ("text shift", "\"a\" << 1") ]
  ] <>
  [ ("text operands finish before the trap", program
      [ "fn main() -> Int {"
      , "  var s = \"x\""
      , "  let y = { s = s + \"y\""
      , "    s } - { print(s)"
      , "    s }"
      , "  return 0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

lines' :: [String] -> Text
lines' = Text.pack . concatMap (<> "\n")
