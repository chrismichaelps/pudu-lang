{-| @Test.Backend.TuplePrograms — tuples with hand-written answers. -}
module Pudu.Backend.TuplePrograms (tupleSuccessPrograms, tupleRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

tupleSuccessPrograms :: [(String, Text, Text)]
tupleSuccessPrograms =
  [ printing "rendering quotes text and characters inside"
      [ "(1, \"a\")", "(\"x\\\"y\", 'q', '\\'')", "((1, 2), (true, ()))", "(-7i8, 255u8, 2.5, 1.0e21)"
      , "(170141183460469231731687303715884105727i128, 0)", "(\"\", \"\\n\\t\\\\\")", "show((1, 2))" ]
      [ "(1, \"a\")", "(\"x\\\"y\", 'q', '\\'')", "((1, 2), (true, ()))", "(-7, 255, 2.5, 1.0e21)"
      , "(170141183460469231731687303715884105727, 0)", "(\"\", \"\\n\\t\\\\\")", "(1, 2)" ]
  , printing "equality is elementwise"
      [ "(1, \"a\") == (1, \"a\")", "(1, \"a\") == (1, \"b\")", "(1, \"a\") != (2, \"a\")"
      , "(0.0 / 0.0, 1) == (0.0 / 0.0, 1)", "(-0.0, 1) == (0.0, 1)", "((1, 'c'), ()) == ((1, 'c'), ())"
      , "(true, false) != (true, false)", "(\"h\\u{e9}\", 3u64) == (\"h\\u{e9}\", 3u64)" ]
      [ "true", "false", "true", "false", "true", "true", "false", "true" ]
  , printing "ordering is compareValues"
      [ "(1, 2) < (1, 3)", "(2, 0) < (1, 9)", "(\"a\", \"b\") < (\"a\", \"c\")", "(true, 1) > (false, 9)"
      , "((1, 2), 3) < ((1, 3), 0)", "('a', 2) <= ('a', 2)", "((), 1) < ((), 2)"
      , "(0.0 / 0.0, 1) < (0.0 / 0.0, 1)", "(0.0 / 0.0, 1) > (0.0 / 0.0, 1)", "(0.0 / 0.0, 1) <= (0.0 / 0.0, 1)"
      , "(0.0 / 0.0, 1) >= (0.0 / 0.0, 1)", "(1.0, 0.0 / 0.0) > (2.0, 0.0)", "(-0.0, 1) < (0.0, 2)"
      , "(\"\\u{1f600}\", 0) > (\"\\u{ffff}\", 0)", "(-1, 0) < (0, 0)"
      , "(0.0 / 0.0, 1) < (1.0, 1)", "(1.0, 1) < (0.0 / 0.0, 1)" ]
      [ "true", "false", "true", "true", "true", "true", "true"
      , "false", "false", "true", "true", "false", "true", "true", "true", "false", "true" ]
  , printing "positions"
      [ "(1, \"two\", 'c')[1]", "((1, 2), 3)[0][1]", "(true, ())[0]", "(\"a\", (\"b\", \"c\"))[1][0]" ]
      [ "two", "2", "true", "b" ]
  , ("let patterns bind each position once", program
      [ "fn make() -> (Int, (Str, Char)) {"
      , "  print(\"made\")"
      , "  (4, (\"four\", '4'))"
      , "}"
      , "fn main() -> Int {"
      , "  let (n, (word, _)) = make()"
      , "  var (a, b) = (\"x\", \"y\")"
      , "  let (b2, a2) = (b, a)"
      , "  a = a + \"!\""
      , "  print(display(n) + word + a + b2 + a2)"
      , "  return 0"
      , "}" ]
    , "made\n4fourx!yx\n")
  , ("tuples through calls, branches, loops and mutation", program
      [ "fn swap(pair: (Str, Int)) -> (Int, Str) { (pair[1], pair[0]) }"
      , "fn pick(flag: Bool) -> (Str, Str) { if flag { (\"yes\", \"y\") } else { (\"no\", \"n\") } }"
      , "fn main() -> Int {"
      , "  var acc = (0, \"\")"
      , "  var i = 0"
      , "  while i < 4 {"
      , "    acc = (acc[0] + i, acc[1] + display(i))"
      , "    i = i + 1"
      , "  }"
      , "  print(show(acc))"
      , "  print(show(swap((\"s\", 2))))"
      , "  print(show(pick(true)) + show(pick(false)))"
      , "  let found = loop { break (\"done\", acc) }"
      , "  print(show(found))"
      , "  var keep = (\"a\" + \"b\", 1)"
      , "  keep = (keep[0] + keep[0], keep[1])"
      , "  print(display(keep))"
      , "  return 0"
      , "}" ]
    , "(6, \"0123\")\n(2, \"s\")\n(\"yes\", \"y\")(\"no\", \"n\")\n(\"done\", (6, \"0123\"))\n(\"abab\", 1)\n")
  , ("members run left to right and a Never member stops the tuple", program
      [ "fn early() -> Int {"
      , "  let t = ({ print(\"first\")"
      , "    1 }, { return 4 }, { print(\"never\")"
      , "    2 })"
      , "  t[0]"
      , "}"
      , "fn main() -> Int {"
      , "  let t = ({ print(\"a\")"
      , "    1 }, { print(\"b\")"
      , "    \"two\" })"
      , "  print(display(early()))"
      , "  print(show(t))"
      , "  return 0"
      , "}" ]
    , "a\nb\nfirst\n4\n(1, \"two\")\n")
  ] <>
  [ ("tuple entry " <> label, program ["fn main() -> " <> kind <> " {", "  " <> body, "}"], answer <> "\n")
  | (label, kind, body, answer) <-
      [ ("of text", "(Int, Str)", "(1, \"a\\\"\")", "(1, \"a\\\"\")")
      , ("nested", "((Bool, Char), ())", "((false, '\\n'), ())", "((false, '\\n'), ())")
      , ("from a call", "(Str, Str)", "{ let s = \"q\"\n  (s, s + s) }", "(\"q\", \"qq\")") ]
  ]
 where
  printing label expressions answers =
    ( label
    , program (["fn main() -> Int {"] <> ["  print(display(" <> expression <> "))" | expression <- expressions] <> ["  return 0", "}"])
    , Text.pack (concatMap (<> "\n") answers) )

{-| Held to the interpreter's rendered diagnostics. -}
tupleRefusalPrograms :: [(String, Text)]
tupleRefusalPrograms =
  [ (label <> " refuses at run time", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let x = " <> expression, "  print(show(x))", "  return 0", "}" ])
  | (label, expression) <-
      [ ("tuple addition", "(1, 2) + (3, 4)"), ("tuple multiplication", "(\"a\", 1) * (\"b\", 2)")
      , ("tuple negation", "-(1, 2)"), ("tuple remainder", "((1, 2), 3) % ((1, 2), 3)") ]
  ] <>
  [ ("tuple operands finish before the refusal", program
      [ "fn side(label: Str) -> (Str, Int) {"
      , "  print(label)"
      , "  (label, 1)"
      , "}"
      , "fn main() -> Int {"
      , "  let x = side(\"left\") - side(\"right\")"
      , "  print(show(x))"
      , "  return 0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
