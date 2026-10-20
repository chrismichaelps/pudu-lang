{-| @Test.Backend.CharPrograms — Char values with hand-written answers. -}
module Pudu.Backend.CharPrograms (charSuccessPrograms, charRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

charSuccessPrograms :: [(String, Text, Text)]
charSuccessPrograms =
  [ printing "literals of every width"
      [ "'a'", "'\\u{e9}'", "'\\u{20ac}'", "'\\u{1f600}'", "'\\u{7f}'", "'\\u{10ffff}'", "' '" ]
      [ "a", "\233", "\8364", "\128512", "\DEL", "\1114111", " " ]
  , printing "show quotes and escapes like renderValue"
      [ "show('a')", "show('\\'')", "show('\"')", "show('\\\\')", "show('\\n')", "show('\\t')"
      , "show('\\r')", "show('\\u{e9}')", "show('\\u{10ffff}')", "show('\\u{0}')" ]
      [ "'a'", "'\\''", "'\\\"'", "'\\\\'", "'\\n'", "'\\t'", "'\r'", "'\233'", "'\1114111'", "'\NUL'" ]
  , printing "ordering is scalar order"
      [ "'a' < 'b'", "'b' <= 'a'", "'\\u{0}' < '\\u{10ffff}'", "'\\u{ffff}' > '\\u{10000}'", "'z' >= 'z'"
      , "'a' == 'a'", "'a' != 'b'", "'\\u{e9}' == '\\u{e9}'", "'A' == 'a'", "'\\u{1f600}' > '\\u{e9}'" ]
      [ "true", "false", "true", "false", "true", "true", "true", "true", "false", "true" ]
  , printing "code and toText"
      [ "'a'.code()", "'\\u{10ffff}'.code()", "'\\u{0}'.code()", "'\\u{e9}'.toText() + \"!\""
      , "'\\u{1f600}'.toText().length()", "show('q'.toText())" ]
      [ "97", "1114111", "0", "\233!", "1", "\"q\"" ]
  , printing "charAt by scalar"
      [ "\"h\\u{e9}llo\".charAt(1)", "\"a\\u{1f600}b\".charAt(1)", "\"a\\u{1f600}b\".charAt(2)"
      , "\"abc\".charAt(0)", "\"abc\".charAt(2)", "show(\"abc\".charAt(1))", "(\"x\" + \"yz\").charAt(2)" ]
      [ "\233", "\128512", "b", "a", "c", "'b'", "z" ]
  , ("Char through calls, mutation and loops", program
      [ "fn next(c: Char) -> Char { if c == 'a' { 'b' } else { 'a' } }"
      , "fn count(text: Str, wanted: Char) -> Int {"
      , "  var i = 0"
      , "  var found = 0"
      , "  while i < text.length() {"
      , "    if text.charAt(i) == wanted { found = found + 1 }"
      , "    i = i + 1"
      , "  }"
      , "  found"
      , "}"
      , "fn main() -> Int {"
      , "  var c = 'a'"
      , "  c = next(c)"
      , "  print(display(c))"
      , "  print(display(count(\"banana\", 'a')))"
      , "  let last = loop { break 'z' }"
      , "  print(show(last))"
      , "  print(display(next(next('q'))))"
      , "  print(\"<\" + display(c) + \">\")"
      , "  print(c.toText())"
      , "  return 0"
      , "}" ]
    , "b\n3\n'z'\nb\n<b>\nb\n")
  , ("charAt runs its index before the receiver", program
      [ "fn main() -> Int {"
      , "  let c = { print(\"text\")"
      , "    \"abc\" }.charAt({ print(\"index\")"
      , "    1 })"
      , "  print(display(c))"
      , "  return 0"
      , "}" ]
    , "index\ntext\nb\n")
  ] <>
  [ ("Char entry " <> label, program ["fn main() -> Char {", "  " <> body, "}"], answer <> "\n")
  | (label, body, answer) <-
      [ ("letter", "'a'", "'a'"), ("quote", "'\\''", "'\\''"), ("backslash", "'\\\\'", "'\\\\'")
      , ("from text", "\"\\u{e9}t\".charAt(0)", "'\233'"), ("newline", "'\\n'", "'\\n'") ]
  ]
 where
  printing label expressions answers =
    ( label
    , program (["fn main() -> Int {"] <> ["  print(display(" <> expression <> "))" | expression <- expressions] <> ["  return 0", "}"])
    , Text.pack (concatMap (<> "\n") answers) )

{-| Held to the interpreter's rendered diagnostics. -}
charRefusalPrograms :: [(String, Text)]
charRefusalPrograms =
  [ (label <> " refuses at run time", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let x = " <> expression, "  print(display(x))", "  return 0", "}" ])
  | (label, expression) <-
      [ ("charAt at the length", "\"ab\".charAt(2)"), ("charAt past a wide scalar", "\"\\u{1f600}\".charAt(1)")
      , ("negative charAt", "\"ab\".charAt(-1)"), ("charAt on empty text", "\"\".charAt(0)")
      , ("charAt at the Int maximum", "\"ab\".charAt(9223372036854775807)")
      , ("Char addition", "'a' + 'b'"), ("Char multiplication", "'a' * 'b'"), ("Char subtraction", "'b' - 'a'")
      , ("Char remainder", "'b' % 'a'"), ("Char negation", "-'a'") ]
  ] <>
  [ ("charAt operands finish before the refusal", program
      [ "fn main() -> Int {"
      , "  let x = { print(\"receiver\")"
      , "    \"abc\" }.charAt({ print(\"index\")"
      , "    5 })"
      , "  print(display(x))"
      , "  return 0"
      , "}" ])
  , ("Char operands finish before the refusal", program
      [ "fn side(c: Char) -> Char {"
      , "  print(display(c))"
      , "  c"
      , "}"
      , "fn main() -> Int {"
      , "  let x = side('l') + side('r')"
      , "  print(display(x))"
      , "  return 0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
