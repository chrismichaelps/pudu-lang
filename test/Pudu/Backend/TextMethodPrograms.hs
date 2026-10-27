{-| @Test.Backend.TextMethodPrograms — Str methods with hand-written answers. -}
module Pudu.Backend.TextMethodPrograms (textMethodSuccessPrograms, textMethodRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

textMethodSuccessPrograms :: [(String, Text, Text)]
textMethodSuccessPrograms =
  [ printing "counting and predicates"
      [ "\"\".length()", "\"abc\".length()", "\"h\\u{e9}llo\".length()", "\"\\u{1d11e}x\".length()"
      , "\"\".isEmpty()", "\"a\".isEmpty()"
      , "\"abc\".contains(\"\")", "\"abc\".contains(\"bc\")", "\"abc\".contains(\"cb\")", "\"a\\u{e9}\".contains(\"\\u{e9}\")"
      , "\"abc\".startsWith(\"\")", "\"abc\".startsWith(\"abc\")", "\"abc\".startsWith(\"abcd\")", "\"abc\".startsWith(\"b\")"
      , "\"abc\".endsWith(\"\")", "\"abc\".endsWith(\"bc\")", "\"abc\".endsWith(\"zabc\")" ]
      [ "0", "3", "5", "2", "true", "false", "true", "true", "false", "true"
      , "true", "true", "false", "false", "true", "true", "false" ]
  , printing "searching by scalar"
      [ "\"abcabc\".indexOf(\"ca\")", "\"abc\".indexOf(\"\")", "\"abc\".indexOf(\"z\")", "\"h\\u{e9}llo\".indexOf(\"llo\")"
      , "\"aaa\".indexOf(\"aa\")", "\"\".indexOf(\"a\")"
      , "\"aabbc\".spanOf(\"ab\")", "\"xyz\".spanOf(\"\")", "\"hello world\".spanNotOf(\" \")", "\"abc\".spanNotOf(\"\")"
      , "\"\\u{e9}\\u{e9}a\".spanOf(\"\\u{e9}\")", "\"\".spanOf(\"a\")" ]
      [ "2", "0", "-1", "2", "0", "-1", "4", "0", "5", "3", "2", "0" ]
  , printing "views clamp at every bound"
      [ "\"h\\u{e9}llo\".drop(1)", "\"abc\".drop(0)", "\"abc\".drop(100)", "\"abc\".drop(9223372036854775807)"
      , "\"h\\u{e9}llo\".take(2)", "\"abc\".take(100)", "\"abc\".take(0)"
      , "\"h\\u{e9}llo\".slice(1, 3)", "\"h\\u{e9}llo\".slice(-5, 2)", "\"h\\u{e9}llo\".slice(3, 1)", "\"h\\u{e9}llo\".slice(2, 100)"
      , "\"abc\".slice(-3, -1)", "\"abc\".slice(100, 200)" ]
      [ "\233llo", "abc", "", "", "h\233", "abc", "", "\233l", "h\233", "", "llo", "", "" ]
  , printing "building new text"
      [ "\"ab\".repeat(3)", "\"\".repeat(5)", "\"x\".repeat(0)"
      , "\"h\\u{e9}llo\".reverse()", "\"\".reverse()", "\"a\\u{1d11e}b\".reverse()"
      , "\"<a href=\\\"x\\\">'&'</a>\".escapeHtml()", "\"plain\".escapeHtml()"
      , "\"aaaa\".replace(\"aa\", \"b\")", "\"abc\".replace(\"\", \"x\")", "\"abcabc\".replace(\"b\", \"\")"
      , "\"h\\u{e9}llo\".replace(\"\\u{e9}\", \"e\")", "\"abc\".replace(\"abc\", \"xyzw\")", "\"abc\".replace(\"q\", \"z\")" ]
      [ "ababab", "", "", "oll\233h", "", "b\119070a"
      , "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;", "plain"
      , "bb", "abc", "acac", "hello", "xyzw", "abc" ]
  , printing "trim and case mapping"
      [ "\"  \\t hi there \\n\".trim()", "\"\\u{3000}x\\u{a0}\".trim()", "\"\\u{2028}x\".trim()", "\"\".trim()", "\"   \".trim()"
      , "\"Stra\\u{df}e \\u{fb01}\".toUpper()", "\"\\u{130}\".toLower()", "\"\\u{391}\\u{3a3}\".toLower()"
      , "\"\\u{1c5}\".toUpper()", "\"\\u{1c5}\".toLower()", "\"\\u{390}\".toUpper()", "\"Hello World\".toLower()", "\"abc\".toUpper()" ]
      [ "hi there", "x", "\8232x", "", "", "STRASSE FI", "i\775", "\945\963"
      , "\452", "\454", "\921\776\769", "hello world", "ABC" ]
  , ("views outlive the text they came from", program
      [ "fn tail(text: Str) -> Str { text.drop(2) }"
      , "fn main() -> Int {"
      , "  let kept = { let built = \"abc\" + \"def\""
      , "    built.slice(1, 4) }"
      , "  print(kept)"
      , "  print(tail(\"xy\" + \"zw\"))"
      , "  var s = \"one two\""
      , "  s = s.drop(4)"
      , "  print(s + \"!\")"
      , "  print(\"\".drop(0).take(3).reverse())"
      , "  return 0"
      , "}" ]
    , "bcd\nzw\ntwo!\n\n")
  , ("arguments run before the receiver", program
      [ "fn main() -> Int {"
      , "  let found = { print(\"receiver\")"
      , "    \"abc\" }.contains({ print(\"argument\")"
      , "    \"b\" })"
      , "  print(display(found))"
      , "  let piece = { print(\"text\")"
      , "    \"hello\" }.slice({ print(\"from\")"
      , "    1 }, { print(\"to\")"
      , "    3 })"
      , "  print(piece)"
      , "  return 0"
      , "}" ]
    , "argument\nreceiver\ntrue\nfrom\nto\ntext\nel\n")
  , ("a Never argument stops before the receiver", program
      [ "fn early() -> Int {"
      , "  let n = { print(\"receiver\")"
      , "    \"abc\" }.drop({ return 7 })"
      , "  return n.length()"
      , "}"
      , "fn main() -> Int {"
      , "  print(display(early()))"
      , "  return 0"
      , "}" ]
    , "7\n")
  ]
 where
  printing label expressions answers =
    ( label
    , program (["fn main() -> Int {"] <> ["  print(display(" <> expression <> "))" | expression <- expressions] <> ["  return 0", "}"])
    , Text.pack (concatMap (<> "\n") answers) )

{-| Held to the interpreter's rendered diagnostics. -}
textMethodRefusalPrograms :: [(String, Text)]
textMethodRefusalPrograms =
  [ (label <> " refuses at run time", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let x = " <> expression, "  print(x)", "  return 0", "}" ])
  | (label, expression) <-
      [ ("negative drop", "\"abc\".drop(-1)"), ("negative take", "\"abc\".take(0 - 2)")
      , ("negative repeat", "\"abc\".repeat(-1)"), ("repeat past the size limit", "\"ab\".repeat(9223372036854775807)")
      , ("negative repeat of empty text", "\"\".repeat(-3)") ]
  ] <>
  [ ("method operands finish before the refusal", program
      [ "fn main() -> Int {"
      , "  let x = { print(\"receiver\")"
      , "    \"abc\" }.drop({ print(\"count\")"
      , "    -1 })"
      , "  print(x)"
      , "  return 0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
