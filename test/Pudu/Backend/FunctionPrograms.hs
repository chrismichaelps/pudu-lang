{-| @Test.Backend.FunctionPrograms — source-level function conformance corpus.
    The native harness compares every observable result with the evaluator;
    these programs make sequencing and call-depth boundaries observable. -}
module Pudu.Backend.FunctionPrograms
  ( functionSuccessPrograms, functionRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

functionSuccessPrograms :: [(String, Text)]
functionSuccessPrograms =
  [ ("Boolean ordering matches comparisonOnly", program
      [ "fn main() -> Int {"
      , "  if !(false < true) || false > true || !(false <= false) || !(true >= false) { return 99 }"
      , "  print(display(false <= true))"
      , "  return 0"
      , "}"
      ])
  , ("operator traps stay inside short circuit", program
      [ "fn main() -> Int {"
      , "  let left = false && (true + false)"
      , "  let right = true || (() < ())"
      , "  if left || !right { return 99 }"
      , "  return 0"
      , "}"
      ])
  , ("Never operands transfer before invalid operators", program
      [ "fn early() -> Int { { return 7 } + ()\n return 0 }"
      , "fn main() -> Int {"
      , "  let result = loop { () + { break 9 } }"
      , "  var count = 0"
      , "  while count < 3 { count = count + 1\n () < { continue }\n print(\"unreachable\") }"
      , "  return result + count + early()"
      , "}"
      ])
  , ("Never comparison discards print carrier without consuming it", program
      [ "fn main() -> Int { print(\"before\") == { return 7 }\n return 0 }" ])
  , ("unit display retains helper branch and discarded effects", program
      [ "fn mark(value: Int) -> () { print(display(value))\n return () }"
      , "fn main() -> () {"
      , "  print(display(()))"
      , "  print(display(if true { print(\"inside\") }))"
      , "  print(display(if true { mark(1) } else { () }))"
      , "  display(mark(2))"
      , "  return ()"
      , "}"
      ])
  , ("unit equality preserves operand ordering and mutation", program
      [ "fn mark(value: Int) -> () { print(display(value))\n return () }"
      , "fn main() -> Int {"
      , "  print(display(mark(1) == mark(2)))"
      , "  print(display(mark(3) != mark(4)))"
      , "  var count = 0"
      , "  let equal = { count = count + 1\n () } == { count = count + 1\n () }"
      , "  if !equal { return 99 }"
      , "  return count"
      , "}"
      ])
  , ("unit operation transfers skip consumers", program
      [ "fn main() -> Int {"
      , "  let first = loop { print(display({ break () })) }"
      , "  let second = loop { { break () } == () }"
      , "  return 0"
      , "}"
      ])
  , ("unit literal entry result", program
      [ "fn main() -> () { () }" ])
  , ("unit aliases locals returns and loop operands", program
      [ "type Token = ()"
      , "fn relay(value: Token) -> Token { return value }"
      , "fn main() -> () {"
      , "  var token: Token = ()"
      , "  token = relay(loop { break () })"
      , "  return token"
      , "}"
      ])
  , ("unit calls freeze effects before later arguments", program
      [ "fn mark(value: Int) -> () { print(display(value))\n return () }"
      , "fn number(value: Int) -> Int { print(display(value))\n return value }"
      , "fn combine(first: (), middle: Int, last: ()) -> Int { return middle }"
      , "fn main() -> Int { return combine(mark(1), number(2), mark(3)) }"
      ])
  , ("unit arguments retain transfers and mutation", program
      [ "fn accept(value: (), number: Int) -> Int { return number }"
      , "fn main() -> Int {"
      , "  var count = 0"
      , "  let result = accept({ count = count + 1\n () }, count)"
      , "  let token = loop { accept({ break () }, 99) }"
      , "  return result"
      , "}"
      ])
  , ("unit parameter recursion restores call depth", program
      [ "fn descend(token: (), value: Int) -> () {"
      , "  if value == 0 { return token }"
      , "  return descend(token, value - 1)"
      , "}"
      , "fn main() -> () { descend((), 20)\n return descend((), 20) }"
      ])
  , ("inferred scalar parameters and results", program
      [ "fn add(value) { return value + 2 }"
      , "fn invert(value) { return !value }"
      , "fn announce(value) { print(display(value + 0))\n {} }"
      , "fn main() -> Int {"
      , "  announce(add(5))"
      , "  if invert(false) { return add(7) }"
      , "  return 0"
      , "}"
      ])
  , ("aliases and annotated mutable scalars", program
      [ "type Score = Int"
      , "type Enabled = Bool"
      , "fn choose(value: Score, enabled: Enabled) -> Score {"
      , "  var total: Score = value + 1"
      , "  let accepted: Enabled = !enabled"
      , "  if accepted { total = total + 2 }"
      , "  return total"
      , "}"
      , "fn main() -> Int { return choose(10, false) }"
      ])
  , ("inferred recursive scalar result", program
      [ "fn sum(value: Int) {"
      , "  if value == 0 { return 0 }"
      , "  return value + sum(value - 1)"
      , "}"
      , "fn main() -> Int { return sum(5) }"
      ])
  , ("typed parameters and Bool results", program
      [ "fn choose(value: Int, accept: Bool) -> Int {"
      , "  if accept { return value }"
      , "  return 0"
      , "}"
      , "fn invert(value: Bool) -> Bool { return !value }"
      , "fn main() -> Int { return choose(17, invert(false)) }"
      ])
  , ("nested calls preserve printed argument order", program
      [ "fn mark(value: Int) -> Int {"
      , "  print(display(value))"
      , "  return value"
      , "}"
      , "fn pair(left: Int, right: Int) -> Int { return left * 10 + right }"
      , "fn main() -> Int { return pair(mark(1), pair(mark(2), mark(3))) }"
      ])
  , ("unit helpers and explicit early returns", program
      [ "fn announce(value: Int) -> () {"
      , "  if value == 0 { return }"
      , "  print(display(value))"
      , "  return"
      , "}"
      , "fn main() -> () {"
      , "  announce(0)"
      , "  announce(7)"
      , "  return"
      , "}"
      ])
  , ("unit helper call can be returned", program
      [ "fn noop() -> () { return }"
      , "fn relay() -> () { return noop() }"
      , "fn main() -> () { return relay() }"
      ])
  , ("argument values freeze before later mutations", program
      [ "fn pair(left: Int, right: Int) -> Int { return left * 10 + right }"
      , "fn main() -> Int {"
      , "  var value = 1"
      , "  return pair(value, {"
      , "    value = 2"
      , "    value"
      , "  })"
      , "}"
      ])
  , ("binary left operands freeze before right mutations", program
      [ "fn main() -> Int {"
      , "  var value = 3"
      , "  return value * {"
      , "    value = 7"
      , "    value"
      , "  }"
      , "}"
      ])
  , ("short circuit suppresses and sequences helper effects", program
      [ "fn mark(value: Bool) -> Bool {"
      , "  print(display(value))"
      , "  return value"
      , "}"
      , "fn main() -> Int {"
      , "  var skippedAnd = false && mark(true)"
      , "  var skippedOr = true || mark(false)"
      , "  var takenAnd = true && mark(false)"
      , "  var takenOr = false || mark(true)"
      , "  if skippedAnd || !skippedOr || takenAnd || !takenOr { return 1 }"
      , "  return 0"
      , "}"
      ])
  , ("direct recursion", program
      [ "fn factorial(value: Int) -> Int {"
      , "  if value == 0 { return 1 }"
      , "  return value * factorial(value - 1)"
      , "}"
      , "fn main() -> Int { return factorial(5) }"
      ])
  , ("mutual recursion", program
      [ "fn even(value: Int) -> Bool {"
      , "  if value == 0 { return true }"
      , "  return odd(value - 1)"
      , "}"
      , "fn odd(value: Int) -> Bool {"
      , "  if value == 0 { return false }"
      , "  return even(value - 1)"
      , "}"
      , "fn main() -> Int {"
      , "  if even(12) && odd(11) { return 0 }"
      , "  return 1"
      , "}"
      ])
  , ("Unicode helper symbols remain portable C11", program
      [ "fn café(value: Int) -> Int { return value + 1 }"
      , "fn λ(value: Int) -> Int { return café(value) }"
      , "fn main() -> Int { return λ(8) }"
      ])
  , ("trigraph text and unused locals remain warning free", program
      [ "fn ignore(unused: Int) -> Int {"
      , "  let discarded = 42"
      , "  return 0"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"??/n ??= ??' ??( ??) ??! ??< ??> ??-\")"
      , "  return ignore(9)"
      , "}"
      ])
  , ("comparison operands keep their grouping", program
      [ "fn main() -> Int {"
      , "  if (1 < 2) == (3 < 4) { return 0 }"
      , "  return 1"
      , "}"
      ])
  , ("called wrapper survives a later resultless body", program
      [ "fn leaf() -> Int { return 4 }"
      , "fn caller() -> Int { return leaf() }"
      , "fn main() -> () {"
      , "  print(display(caller()))"
      , "  return"
      , "}"
      ])
  , ("depth boundary accepts and restores depth across calls", depthProgram
      [ "  print(display(descend(" <> depth (callDepthLimit - 1) <> ")))"
      , "  return descend(" <> depth (callDepthLimit - 1) <> ")"
      ])
  ]

functionRefusalPrograms :: [(String, Text)]
functionRefusalPrograms = operatorRefusals <>
  [ ("unit display failure precedes printing", program
      [ "fn fail() -> () { 10 / 0\n return () }"
      , "fn main() -> () { print(display(fail()))\n return () }"
      ])
  , ("unit equality failure precedes right operand effects", program
      [ "fn fail() -> () { 10 / 0\n return () }"
      , "fn later() -> () { print(\"later\")\n return () }"
      , "fn main() -> () { print(display(fail() == later()))\n return () }"
      ])
  , ("unit argument failure prevents later argument effects", program
      [ "fn fail() -> () { 10 / 0\n return () }"
      , "fn later() -> Int { print(\"later\")\n return 1 }"
      , "fn accept(token: (), value: Int) -> Int { return value }"
      , "fn main() -> Int { return accept(fail(), later()) }"
      ])
  , ("one call beyond the depth boundary", depthProgram
      ["  return descend(" <> depth callDepthLimit <> ")"])
  , ("checked failure inside a called helper", program
      [ "fn divide(value: Int) -> Int { return 10 / value }"
      , "fn main() -> Int { return divide(0) }"
      ])
  ]

operatorRefusals :: [(String, Text)]
operatorRefusals =
  [ ("unit operator " <> Text.unpack operator, fault ("() " <> operator <> " ()"))
  | operator <- ["+", "-", "*", "/", "%", "<", "<=", ">", ">=", "&", "|", "^", "&+", "+|"]
  ] <>
  [ ("Boolean operator " <> Text.unpack operator, fault ("true " <> operator <> " false"))
  | operator <- ["+", "-", "*", "/", "%", "&", "|", "^", "&+", "+|"]
  ] <>
  [ ("unary or shift " <> Text.unpack expression, fault expression)
  | expression <- ["-()", "-true", "~()", "~false", "() << 1", "true << 1"]
  ] <>
  [ ("expanded macro operator failure", program
      [ "macro invalid() = () + ()"
      , "fn main() -> Int { invalid!()\n return 0 }"
      ])
  , ("Unicode and tabbed operator failure", program
      [ "fn λ() -> () {"
      , "\t() + ()"
      , "}"
      , "fn main() -> Int { λ()\n return 0 }"
      ])
  , ("invalid unit operands print in source order", program
      [ "fn mark(value: Int) -> () { print(display(value))\n return () }"
      , "fn main() -> Int { mark(1) + mark(2)\n return 0 }"
      ])
  , ("invalid Boolean operands retain comparisonOnly wording", program
      [ "fn mark(value: Bool) -> Bool { print(display(value))\n return value }"
      , "fn main() -> Int { mark(true) + mark(false)\n return 0 }"
      ])
  , ("operand arithmetic failure precedes operator refusal", program
      [ "fn first() -> () { 1 / 0\n return () }"
      , "fn later() -> () { print(\"later\")\n return () }"
      , "fn main() -> Int { first() + later()\n return 0 }"
      ])
  ]
 where
  fault expression = program ["fn main() -> Int {", "  " <> expression, "  return 0", "}"]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

depth :: Int -> Text
depth = Text.pack . show

depthProgram :: [Text] -> Text
depthProgram body = program
  ([ "fn descend(value: Int) -> Int {"
   , "  if value == 0 { return 0 }"
   , "  return descend(value - 1)"
   , "}"
   , "fn main() -> Int {"
   ] <> body <> ["}"])
