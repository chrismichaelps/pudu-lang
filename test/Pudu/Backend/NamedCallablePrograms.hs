{-| @Test.Backend.NamedCallablePrograms — named values enter their actual
    function, preserving source depth and argument ownership. -}
module Pudu.Backend.NamedCallablePrograms
  ( namedCallableSuccessPrograms, namedCallableRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

namedCallableSuccessPrograms :: [(String, Text, Text)]
namedCallableSuccessPrograms =
  [ ("named-value recursion reaches and restores the ordinary depth boundary", recursion
      [ "fn main() -> Int {"
      , "  print(display(descend(" <> number (callDepthLimit - 1) <> ")))"
      , "  descend(" <> number (callDepthLimit - 1) <> ")", "}" ]
    , "0\n")
  , ("named and lifted callables keep their own parameter ABI", program
      [ "fn zero() -> Str { \"zero\" }"
      , "fn join(left: Str, right: Str) -> Str { left + right }"
      , "fn apply(callback: fn() -> Str) -> Str { callback() }"
      , "fn factory() -> fn(Str, Str) -> Str { join }"
      , "fn main() -> Int {"
      , "  let empty = zero", "  let invoke = apply"
      , "  print(empty() + \" \" + invoke(empty))"
      , "  let prefix = \"pre:\""
      , "  let callbacks = [join, fn(left: Str, right: Str) -> Str => prefix + right + left]"
      , "  for callback in callbacks { print(callback(\"a\", \"b\")) }"
      , "  print(factory()(\"c\", \"d\"))"
      , "  print(show(empty) + \" \" + display(empty == zero) + \" \" + display(callbacks[0] == join))"
      , "  0", "}" ]
    , "zero zero\nab\npre:ba\ncd\n<fn zero> true true\n")
  , ("a zero-argument named entry value retains its rendering", program
      ["fn zero() -> Str { \"zero\" }", "fn main() -> fn() -> Str { zero }"]
    , "<fn zero>\n")
  ]

namedCallableRefusalPrograms :: [(String, Text)]
namedCallableRefusalPrograms =
  [ ("excessive named-value recursion blames the invocation", recursion
      ["fn main() -> Int { descend(" <> number callDepthLimit <> ") }"])
  , ("a named-value failure keeps earlier argument effects and body provenance", program
      [ "fn fail(left: Str, right: Int) -> Str { left + display(12 / right) }"
      , "fn main() -> Str {"
      , "  let callback = fail"
      , "  callback({ print(\"argument\")\n \"left\" }, 0)", "}" ])
  ]

recursion :: [Text] -> Text
recursion body = program
  ([ "fn descend(n: Int) -> Int {"
   , "  if n == 0 { return 0 }"
   , "  let next = descend"
   , "  next(n - 1)", "}" ] <> body)

number :: Int -> Text
number = Text.pack . show

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
