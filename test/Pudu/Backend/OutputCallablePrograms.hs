{-| @Test.Backend.OutputCallablePrograms — output builtins retain their own
    identity and call behavior when passed around as values. -}
module Pudu.Backend.OutputCallablePrograms
  ( outputCallableSuccessPrograms, outputCallableRefusalPrograms, outputCallableFailureCleanup ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.RenderingCallablePrograms (renderingCallableSuccessPrograms, renderingCallableRefusalPrograms)
import Pudu.Comptime.Limits (callDepthLimit)

outputCallableSuccessPrograms :: [(String, Text, Text, Text)]
outputCallableSuccessPrograms = renderingCallableSuccessPrograms <>
  [ ("builtin tags render and compare independently of source functions", program
      [ "fn custom(text: Str) -> Result[(), Str] { print(text) }"
      , "fn main() -> Int {"
      , "  let outputs = [print, printPart, printError, printErrorPart]"
      , "  for output in outputs { print(show(output)) }"
      , "  print(display(print == print) + \" \" + display(print == printPart) + \" \" + display(print == custom))"
      , "  0", "}" ]
    , "<builtin print>\n<builtin printPart>\n<builtin printError>\n<builtin printErrorPart>\ntrue false false\n", "")
  , ("builtin values cross aliases records captures returns and generic calls", program
      [ "type Printer = { write: fn(Str) -> Result[(), Str] }"
      , "fn identity[T](value: T) -> T { value }"
      , "fn make(output: fn(Str) -> Result[(), Str]) -> fn(Str) -> Result[(), Str] { |text| output(text) }"
      , "fn choose() -> fn(Str) -> Result[(), Str] { print }"
      , "fn main() -> Int {"
      , "  let part = identity(printPart)", "  let line = identity(print)"
      , "  let errorPart = identity(printErrorPart)", "  let errorLine = identity(printError)"
      , "  part(\"a\")", "  line(\"B\")", "  errorPart(\"e\")", "  errorLine(\"E\")"
      , "  let holder = Printer{write: print}"
      , "  print(show(holder.write({ print(\"argument\")\n \"held\" })))"
      , "  make(printPart)(\"closure:\")", "  line(\"end\")"
      , "  choose()(\"return\")", "  0", "}" ]
    , "aB\nargument\nheld\nOk(())\nclosure:end\nreturn\n", "eE\n")
  , ("builtin entry keeps its builtin rendering", program
      ["fn main() -> fn(Str) -> Result[(), Str] { print }"]
    , "<builtin print>\n", "")
  , ("stderr builtin entry is still a value on stdout", program
      ["fn main() -> fn(Str) -> Result[(), Str] { printError }"]
    , "<builtin printError>\n", "")
  , ("nearer source and local declarations shadow builtin values", program
      [ "fn print(text: Str) -> Result[(), Str] { printError(text) }"
      , "fn main() -> Int {"
      , "  let output = print", "  printPart(show(output) + \"\\n\")"
      , "  output(\"user\")", "  let printPart = printErrorPart"
      , "  printPart(\"local\")", "  0", "}" ]
    , "<fn print>\n", "user\nlocal")
  , ("builtin calls at the source depth boundary do not descend", deep
      [ "fn main() -> Int {"
      , "  print(show(descend(" <> number (callDepthLimit - 1) <> ", print)))"
      , "  let output = print", "  output(\"restored\")", "  0", "}" ]
    , "leaf\nOk(())\nrestored\n", "")
  ]

outputCallableRefusalPrograms :: [(String, Text)]
outputCallableRefusalPrograms = renderingCallableRefusalPrograms <>
  [ ("unary builtin failures use the builtin kind", program
      ["fn main() -> Int { let invalid = -print\n print(show(invalid))\n 0 }"])
  , ("mixed callable operator kinds come from their runtime values", program $ choices <>
      ["fn main() -> Int { let invalid = pick(true) + pick(false)\n print(show(invalid))\n 0 }"])
  , ("unary source function failure stays distinct from builtin", program $ choices <>
      ["fn main() -> Int { let invalid = -pick(false)\n print(show(invalid))\n 0 }"])
  , ("builtin set keys refuse with their actual kind", program
      ["fn main() -> Int { let invalid = setOf([print])\n print(show(invalid))\n 0 }"])
  , ("builtin map keys refuse with their actual kind", program
      ["fn main() -> Int { let invalid = mapOf([(print, 1)])\n print(show(invalid))\n 0 }"])
  , ("tuples holding builtin values still refuse ordering", program $ choices <>
      ["fn main() -> Int { let invalid = (print, 1) < (custom, 2)\n print(show(invalid))\n 0 }"])
  , ("a source callable in the same typed slot still checks depth", deep
      [ "fn custom(text: Str) -> Result[(), Str] { print(text) }"
      , "fn main() -> Int { descend(" <> number (callDepthLimit - 1) <> ", custom)\n 0 }" ])
  ]

outputCallableFailureCleanup :: [(String, Text, Text, Text)]
outputCallableFailureCleanup =
  [ ("failed output callables release their error strings and Results", program
      [ "fn main() -> Int {"
      , "  let outputs = [print, printPart, printError, printErrorPart]"
      , "  for output in outputs {"
      , "    for count in 0..10 {"
      , "      match output(\"x\".repeat(8192)) {"
      , "        case Ok(_) => { return 1 }"
      , "        case Err(message) => if message.length() == 0 { return 2 }"
      , "      }", "    }", "  }", "  0", "}" ]
    , "", "") ]

choices :: [Text]
choices =
  [ "fn custom(text: Str) -> Result[(), Str] { print(text) }"
  , "fn pick(builtin: Bool) -> fn(Str) -> Result[(), Str] {"
  , "  print(display(builtin))", "  if builtin { print } else { custom }", "}" ]

deep :: [Text] -> Text
deep body = program
  ([ "fn descend(n: Int, output: fn(Str) -> Result[(), Str]) -> Result[(), Str] {"
   , "  if n == 0 { return output(\"leaf\") }"
   , "  descend(n - 1, output)", "}" ] <> body)

number :: Int -> Text
number = Text.pack . show

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
