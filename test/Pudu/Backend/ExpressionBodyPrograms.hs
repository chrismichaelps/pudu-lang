{-| @Test.Backend.ExpressionBodyPrograms — named expression bodies share the
    ordinary function return and lifetime boundaries. -}
module Pudu.Backend.ExpressionBodyPrograms
  ( expressionBodySuccessPrograms, expressionBodyRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

expressionBodySuccessPrograms :: [(String, Text, Text)]
expressionBodySuccessPrograms =
  [ ("expression entry renders its owned result", program
      ["fn main() -> Str = \"hé\" + \"llo\""]
    , "\"héllo\"\n")
  , ("expression helpers freeze argument effects", program
      [ "fn mark(value: Int) -> Int = { print(display(value))\n value }"
      , "fn pair(left: Int, right: Int) -> Int = left * 10 + right"
      , "fn main() -> Int = { print(display(pair(mark(1), mark(2))))\n 0 }" ]
    , "1\n2\n12\n")
  , ("expression bodies preserve return propagation and captures", program
      [ "fn early() -> Str = { return \"early\"\n \"unreachable\" }"
      , "fn relay(value: Result[Str, Str]) -> Result[Str, Str] = Ok(value? + \"!\")"
      , "fn make(prefix: Str) -> fn(Str) -> Str = fn(value: Str) -> Str => prefix + value"
      , "fn main() -> Int = {"
      , "  print(early())", "  print(show(relay(Ok(\"yes\"))))"
      , "  print(show(relay(Err(\"no\"))))"
      , "  let callback = make(\"pre:\")", "  print(callback(\"value\"))"
      , "  let named = early", "  print(named())", "  0", "}" ]
    , "early\nOk(\"yes!\")\nErr(\"no\")\npre:value\nearly\n")
  , ("generic and trait expression bodies use their solved copies", program
      [ "fn identity[T](value: T) -> T = value"
      , "trait Named {"
      , "  fn name(self: &Self) -> Str"
      , "  fn loud(self: &Self) -> Str = self.name() + \"!\"", "}"
      , "type Item = { label: Str }"
      , "impl Named for Item { fn name(self: &Self) -> Str = self.label }"
      , "fn main() -> Int = {"
      , "  print(show(identity((3, \"s\"))))"
      , "  print(identity(Item{label: \"item\"}).loud())", "  0", "}" ]
    , "(3, \"s\")\nitem!\n")
  , ("mutually recursive expression bodies retain their results", program
      [ "fn even(n: Int) -> Bool = if n == 0 { true } else { odd(n - 1) }"
      , "fn odd(n: Int) -> Bool = if n == 0 { false } else { even(n - 1) }"
      , "fn main() -> Int = { print(display(even(20)) + \" \" + display(odd(21)))\n 0 }" ]
    , "true true\n")
  , ("expression body recursion restores depth at the boundary", recursion
      [ "fn main() -> Int = {"
      , "  print(display(descend(" <> number (callDepthLimit - 1) <> ")))"
      , "  descend(" <> number (callDepthLimit - 1) <> ")", "}" ]
    , "0\n")
  , ("expression entry preserves an output Result", program
      ["fn main() -> Result[(), Str] = print(\"entry\")"]
    , "entry\nOk(())\n")
  , ("unit expression entry remains silent", program
      ["fn main() -> () = ()"]
    , "")
  ]

expressionBodyRefusalPrograms :: [(String, Text)]
expressionBodyRefusalPrograms =
  [ ("expression failure keeps Unicode and tab source provenance", program
      [ "fn café(value: Int) -> Int =\t12 / value"
      , "fn main() -> Int = { print(\"before\")\n café(0) }" ])
  , ("expression recursion fails at the ordinary call depth", recursion
      ["fn main() -> Int = descend(" <> number callDepthLimit <> ")"])
  , ("expression body argument failure skips later effects", program
      [ "fn fail() -> Str = { print(\"first\")\n 1 / 0\n \"never\" }"
      , "fn later() -> Str = { print(\"later\")\n \"later\" }"
      , "fn join(left: Str, right: Str) -> Str = left + right"
      , "fn main() -> Str = join(fail(), later())" ])
  ]

recursion :: [Text] -> Text
recursion body = program
  (["fn descend(n: Int) -> Int = if n == 0 { 0 } else { descend(n - 1) }"] <> body)

number :: Int -> Text
number = Text.pack . show

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
