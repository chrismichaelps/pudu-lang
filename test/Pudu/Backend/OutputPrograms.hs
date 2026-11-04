{-| @Test.Backend.OutputPrograms — output results remain ordinary values. -}
module Pudu.Backend.OutputPrograms
  ( outputSuccessPrograms, outputStreamPrograms, outputRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text

outputSuccessPrograms :: [(String, Text, Text)]
outputSuccessPrograms =
  [ ("output Results cross bindings, calls, closures, propagation and loop breaks", program
      [ "fn pass(value: Result[(), Str]) -> Result[(), Str] { value }"
      , "fn emit() -> Result[(), Str] { print(\"callee\")?\n Ok(()) }"
      , "fn main() -> Int {"
      , "  let stored = print(\"stored\")"
      , "  print(show(stored) + \" \" + display(stored == Ok(())))"
      , "  let results = [stored, printPart(\"part\")]"
      , "  print(show(results))"
      , "  print(show(pass(print(\"argument\"))))"
      , "  print(show(emit()))"
      , "  let broken = loop { break print(\"break\") }"
      , "  print(show(broken))"
      , "  let callback = fn() -> Result[(), Str] => print(\"closure\")"
      , "  print(show(callback()))"
      , "  print(display({ print(\"nested\") }))"
      , "  return 0", "}" ]
    , "stored\nOk(()) true\npart[Ok(()), Ok(())]\nargument\nOk(())\ncallee\nOk(())\nbreak\nOk(())\nclosure\nOk(())\nnested\nOk(())\n")
  , ("a trailing output Result is the entry result", program
      ["fn main() -> Result[(), Str] { print(\"entry\") }"]
    , "entry\nOk(())\n")
  , ("an explicit output Result is the entry result", program
      ["fn main() -> Result[(), Str] { return printPart(\"entry:\") }"]
    , "entry:Ok(())\n")
  , ("a large Str entry crosses the report buffer without losing ownership", program
      ["fn main() -> Str { \"x\".repeat(20000) }"]
    , "\"" <> Text.replicate 20000 "x" <> "\"\n")
  , ("a no-else branch still discards the output Result", program
      [ "fn main() -> Int {", "  let token = if true { print(\"taken\") }"
      , "  print(show(token))", "  return 0", "}" ]
    , "taken\n()\n")
  ]

outputStreamPrograms :: [(String, Text, Text, Text)]
outputStreamPrograms =
  [ ("both standard streams preserve partial UTF-8 and NUL output", program
      [ "fn main() -> Int {"
      , "  let errorPart = printErrorPart(\"err:\")"
      , "  let errorLine = printError(\"é\\0\")"
      , "  printPart(\"out:\")", "  print(\"é\\0\")"
      , "  print(show(errorPart) + \" \" + show(errorLine))"
      , "  return 0", "}" ]
    , "out:é\0\nOk(()) Ok(())\n", "err:é\0\n")
  ]

outputRefusalPrograms :: [(String, Text)]
outputRefusalPrograms =
  [ ("an accepted unary operator on output retains the Result variant", program
      [ "fn main() -> Int {", "  let invalid = -print(\"operand\")"
      , "  print(show(invalid))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
