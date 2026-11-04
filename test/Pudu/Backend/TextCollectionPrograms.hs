{-| @Test.Backend.TextCollectionPrograms — Str methods answering arrays and
    options, against `callStringMethod` and `Eval.Builtin.TextNumber`. -}
module Pudu.Backend.TextCollectionPrograms (textCollectionSuccessPrograms, textCollectionRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

textCollectionSuccessPrograms :: [(String, Text, Text)]
textCollectionSuccessPrograms =
  [ ("split, lines and chars match Text.splitOn, Text.lines and unpack", program
      [ "fn main() -> Int {", "  print(show(\"a,b,,c\".split(\",\")) + \" \" + show(\",a,\".split(\",\")) + \" \" + show(\"\".split(\",\")) + \" \" + show(\"abc\".split(\"\")) + \" \" + show(\"\".split(\"\")))", "  print(show(\"aaa\".split(\"aa\")) + \" \" + show(\"héé→x→\".split(\"→\")) + \" \" + show(\"one::two\".split(\"::\")) + \" \" + show(\"x\".split(\"long separator\")))"
      , "  print(show(\"ñé漢\".split(\"\")) + \" \" + show(\"no match\".split(\"|\")))", "  print(show(\"a\\nb\".lines()) + \" \" + show(\"a\\n\".lines()) + \" \" + show(\"\\n\".lines()) + \" \" + show(\"\".lines()) + \" \" + show(\"a\\n\\nb\\n\\n\".lines()) + \" \" + show(\"x\\r\\ny\".lines()))", "  print(show(\"héllo\".chars()) + \" \" + show(\"\".chars()) + \" \" + show(\"a😀b\".chars()))"
      , "  let words = \"the quick brown fox\".split(\" \")", "  var total = 0", "  for word in words { total = total + word.length() }"
      , "  print(display(total) + \" \" + words.join(\"+\") + \" \" + display(words.length()))", "  let letters = \"abc\".chars()", "  for c in letters { print(display(c.code())) }"
      , "  let first = \"k=v\".split(\"=\")[0]", "  print(first)", "  return 0"
      , "}" ]
    , "[\"a\", \"b\", \"\", \"c\"] [\"\", \"a\", \"\"] [\"\"] [\"a\", \"b\", \"c\"] []\n[\"\", \"a\"] [\"héé\", \"x\", \"\"] [\"one\", \"two\"] [\"x\"]\n[\"ñ\", \"é\", \"漢\"] [\"no match\"]\n[\"a\", \"b\"] [\"a\"] [\"\"] [] [\"a\", \"\", \"b\", \"\"] [\"x\r\", \"y\"]\n['h', 'é', 'l', 'l', 'o'] [] ['a', '😀', 'b']\n16 the+quick+brown+fox 4\n97\n98\n99\nk\n")
  , ("toInt and toFloat read exactly what readWhole and readFloat read", program
      [ "fn int(text: Str) -> Str {", "  match text.toInt() {", "    case Some(n) => display(n)"
      , "    case None => \"none\"", "  }", "}"
      , "", "fn float(text: Str) -> Str {", "  match text.toFloat() {"
      , "    case Some(x) => display(x)", "    case None => \"none\"", "  }"
      , "}", "", "fn main() -> Int {"
      , "  let ints = [\"42\", \"-7\", \"+3\", \"007\", \"-0\", \"\", \"-\", \"+\", \" 1\", \"1 \", \"1_000\", \"12a\", \"9223372036854775807\", \"9223372036854775808\", \"-9223372036854775808\", \"-9223372036854775809\", \"00000000000000000000000000001\", \"99999999999999999999999\", \"٣\", \"0x10\"]", "  for t in ints { print(t + \" -> \" + int(t)) }", "  let floats = [\"1.5\", \"-2.25\", \".5\", \"5.\", \"+.5\", \".\", \"\", \"-\", \"1e5\", \"1E-3\", \"1e+2\", \"1e\", \"1e+\", \"2.5e1234567\", \"2.5e123456\", \"1e308\", \"1.8e308\", \"1e-400\", \"4.9e-324\", \"2.4e-324\", \"-0.0\", \"-0\", \"0.1\", \"0.30000000000000004\", \"1.2.3\", \"1e5e3\", \" 1.0\", \"1.0 \", \"inf\", \"nan\", \"123456789012345678901234567890\", \"0.000001e000006\", \"1_0.0\", \"17976931348623157e292\", \"17976931348623159e292\"]"
      , "  for t in floats { print(t + \" -> \" + float(t)) }", "  print(show(\"12\".toInt()) + \" \" + show(\"x\".toFloat()) + \" \" + show(\"2.0\".toFloat()))", "  let maybe = \"8\".toInt()"
      , "  if let Some(v) = maybe { print(display(v * 2)) }", "  return 0", "}" ]
    , "42 -> 42\n-7 -> -7\n+3 -> 3\n007 -> 7\n-0 -> 0\n -> none\n- -> none\n+ -> none\n 1 -> none\n1  -> none\n1_000 -> none\n12a -> none\n9223372036854775807 -> 9223372036854775807\n9223372036854775808 -> none\n-9223372036854775808 -> -9223372036854775808\n-9223372036854775809 -> none\n00000000000000000000000000001 -> 1\n99999999999999999999999 -> none\n٣ -> none\n0x10 -> none\n1.5 -> 1.5\n-2.25 -> -2.25\n.5 -> 0.5\n5. -> 5.0\n+.5 -> 0.5\n. -> none\n -> none\n- -> none\n1e5 -> 100000.0\n1E-3 -> 1.0e-3\n1e+2 -> 100.0\n1e -> none\n1e+ -> none\n2.5e1234567 -> none\n2.5e123456 -> none\n1e308 -> 1.0e308\n1.8e308 -> none\n1e-400 -> 0.0\n4.9e-324 -> 5.0e-324\n2.4e-324 -> 0.0\n-0.0 -> -0.0\n-0 -> -0.0\n0.1 -> 0.1\n0.30000000000000004 -> 0.30000000000000004\n1.2.3 -> none\n1e5e3 -> none\n 1.0 -> none\n1.0  -> none\ninf -> none\nnan -> none\n123456789012345678901234567890 -> 1.2345678901234568e29\n0.000001e000006 -> 1.0\n1_0.0 -> none\n17976931348623157e292 -> 1.7976931348623157e308\n17976931348623159e292 -> none\nSome(12) None Some(2.0)\n16\n")
  ]

textCollectionRefusalPrograms :: [(String, Text)]
textCollectionRefusalPrograms =
  [ ("an index past a split's pieces fails at the index", program
      [ "fn main() -> Int {", "  let parts = \"a,b\".split(\",\")", "  print(show(parts))"
      , "  print(parts[2])", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
