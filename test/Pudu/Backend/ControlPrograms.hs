{-| @Test.Backend.ControlPrograms — terminating scalar control-flow programs
    shared by the interpreter/native differential execution harness.
-}
module Pudu.Backend.ControlPrograms
  ( controlSuccessPrograms
  , controlRefusalPrograms
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

controlSuccessPrograms :: [(String, Text)]
controlSuccessPrograms =
  [ ("Int and Bool loop results", mainProgram
      [ "  let number = loop { break 7 }"
      , "  let flag = loop { break true }"
      , "  print(display(flag))"
      , "  return number"
      ])
  , ("unit loop result", program
      [ "fn finish() -> () { loop { break } }"
      , "fn main() -> Int {"
      , "  finish()"
      , "  return 0"
      , "}"
      ])
  , ("continue reevaluates mutable while condition", mainProgram
      [ "  var index = 0"
      , "  var total = 0"
      , "  while index < 6 {"
      , "    index = index + 1"
      , "    if index == 2 { continue }"
      , "    if index == 5 { break }"
      , "    total = total + index"
      , "  }"
      , "  print(display(index))"
      , "  return total"
      ])
  , ("loop continue targets nearest loop", mainProgram
      [ "  var index = 0"
      , "  let answer = loop {"
      , "    index = index + 1"
      , "    if index < 3 { continue }"
      , "    break index"
      , "  }"
      , "  return answer"
      ])
  , ("labelled break carries outer result", mainProgram
      [ "  let found = @outer loop {"
      , "    loop { break @outer 11 }"
      , "  }"
      , "  return found"
      ])
  , ("labelled continue skips inner and outer remainders", mainProgram
      [ "  var index = 0"
      , "  var total = 0"
      , "  @outer while index < 4 {"
      , "    index = index + 1"
      , "    loop {"
      , "      if index < 3 { continue @outer }"
      , "      break"
      , "    }"
      , "    total = total + index"
      , "  }"
      , "  return total"
      ])
  , ("repeated labels resolve to the nearest loop", mainProgram
      [ "  let result = @same loop {"
      , "    let inner = @same loop { break @same 3 }"
      , "    print(display(inner))"
      , "    break inner + 4"
      , "  }"
      , "  return result"
      ])
  , ("while condition break targets enclosing loop", mainProgram
      [ "  let answer = loop {"
      , "    while { break 13 } { print(\"unreachable\") }"
      , "  }"
      , "  return answer"
      ])
  , ("while condition continue targets enclosing loop", mainProgram
      [ "  var index = 0"
      , "  let answer = @outer loop {"
      , "    index = index + 1"
      , "    while {"
      , "      if index < 3 { continue @outer }"
      , "      false"
      , "    } { print(\"unreachable\") }"
      , "    break index"
      , "  }"
      , "  return answer"
      ])
  , ("break operand transfers to outer loop", mainProgram
      [ "  let answer = @outer loop {"
      , "    loop { break { break @outer 17 } }"
      , "  }"
      , "  return answer"
      ])
  , ("break operand returns from helper", program
      [ "fn choose() -> Int {"
      , "  loop { break { return 19 } }"
      , "}"
      , "fn main() -> Int { return choose() }"
      ])
  , ("Never then branch joins scalar else branch", program
      [ "fn choose(flag: Bool) -> Int {"
      , "  return loop {"
      , "    let value = if flag { break 7 } else { 3 }"
      , "    break value"
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  print(display(choose(true)))"
      , "  return choose(false)"
      , "}"
      ])
  , ("Never else branch joins scalar then branch", program
      [ "fn choose(flag: Bool) -> Int {"
      , "  return loop {"
      , "    let value = if flag { 5 } else { break 9 }"
      , "    break value"
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  print(display(choose(false)))"
      , "  return choose(true)"
      , "}"
      ])
  , ("short circuit skips control transfer", mainProgram
      [ "  let answer = loop {"
      , "    let first = false && { break 31 }"
      , "    let second = true || { break 37 }"
      , "    print(display(first))"
      , "    print(display(second))"
      , "    break 23"
      , "  }"
      , "  return answer"
      ])
  , ("loop body results are evaluated and discarded", program
      [ "fn note(value: Int) -> Int {"
      , "  print(display(value))"
      , "  return value"
      , "}"
      , "fn main() -> Int {"
      , "  var index = 0"
      , "  let answer = loop {"
      , "    index = index + 1"
      , "    if index == 3 { break index }"
      , "    note(index)"
      , "  }"
      , "  return answer"
      , "}"
      ])
  , ("discarded while body results retain effects", program
      [ "fn note(value: Int) -> Int {"
      , "  print(display(value))"
      , "  return value"
      , "}"
      , "fn main() -> Int {"
      , "  var index = 0"
      , "  while index < 3 {"
      , "    index = index + 1"
      , "    note(index)"
      , "  }"
      , "  return index"
      , "}"
      ])
  , ("discarded break value retains effects", program
      [ "fn note() -> Int {"
      , "  print(\"break operand\")"
      , "  return 29"
      , "}"
      , "fn main() -> Int {"
      , "  loop { break note() }"
      , "  return 0"
      , "}"
      ])
  , ("unexecuted divergent loop joins reachable scalar", program
      [ "fn choose(flag: Bool) -> Int {"
      , "  return if flag { loop {} } else { 41 }"
      , "}"
      , "fn main() -> Int { return choose(false) }"
      ])
  , ("nested unit return operand", program
      [ "fn done() -> () { return { return } }"
      , "fn main() -> Int {"
      , "  done()"
      , "  print(\"returned\")"
      , "  return 0"
      , "}"
      ])
  , ("numeric operand returns from helper", program
      [ "fn choose() -> Int { return 1 + { return 47 } }"
      , "fn main() -> Int { return choose() }"
      ])
  , ("unary operand continues the enclosing loop", mainProgram
      [ "  var index = 0"
      , "  let answer = @outer loop {"
      , "    index = index + 1"
      , "    if index < 3 { let skipped = -{ continue @outer } }"
      , "    break index"
      , "  }"
      , "  return answer"
      ])
  , ("assignment operand breaks before replacement", mainProgram
      [ "  var value = 1"
      , "  let answer = loop {"
      , "    value = { break 53 }"
      , "    break 99"
      , "  }"
      , "  print(display(value))"
      , "  return answer"
      ])
  , ("if without else preserves unit values and branch effects", program
      [ "fn done(flag: Bool) -> () {"
      , "  return if flag {"
      , "    print(\"returned branch\")"
      , "    while false {}"
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  let first = if true {"
      , "    print(\"bound branch\")"
      , "    while false {}"
      , "  }"
      , "  let second = if false {"
      , "    print(\"unreachable\")"
      , "    while false {}"
      , "  }"
      , "  done(true)"
      , "  done(false)"
      , "  return 0"
      , "}"
      ])
  , ("mutable unit local retains initialization and assignment calls", program
      [ "fn note(value: Int) -> () {"
      , "  print(display(value))"
      , "  return"
      , "}"
      , "fn main() -> () {"
      , "  var token = note(1)"
      , "  token = note(2)"
      , "  return token"
      , "}"
      ])
  , ("no-else scalar results discard through unit function", program
      [ "fn finish(flag: Bool) -> () { if flag { 7 } }"
      , "fn main() { finish(true)\n finish(false) }"
      ])
  , ("no-else print Result discards through explicit return", program
      [ "fn main() -> () { return if true { print(\"taken\") } }" ])
  , ("no-else mutable unit local retains effects", program
      [ "fn main() {"
      , " var token = if true { 7 }"
      , " token = if true { print(\"assigned\") }"
      , " return token", "}"
      ])
  , ("no-else break value is unit", program
      [ "fn main() { loop { break if true { print(\"break operand\") } } }" ])
  , ("no-else condition runs once", mainProgram
      [ " var count = 0"
      , " let token = if { count = count + 1\n true } { print(\"taken\") }"
      , " return count"
      ])
  ] <> map scalarTransferProgram
    [ ("Never left and operand", "{ break 43 } && noteBool()")
    , ("Never right and operand", "true && { break 43 }")
    , ("Never left or operand", "{ break 43 } || noteBool()")
    , ("Never right or operand", "false || { break 43 }")
    , ("Never left numeric operand", "{ break 43 } + noteInt()")
    , ("Never right numeric operand", "noteInt() + { break 43 }")
    , ("Never negation operand", "-{ break 43 }")
    , ("Never Boolean negation operand", "!{ break 43 }")
    , ("Never if condition", "if { break 43 } { 1 } else { 2 }")
    , ("Never first call argument", "take({ break 43 }, noteInt())")
    , ("Never second call argument", "take(noteInt(), { break 43 })")
    , ("Never if without else condition", "if { break 43 } { print(\"unreachable\") }")
    , ("Never print operand", "print({ break 43 })")
    , ("Never display operand", "display({ break 43 })")
    , ("Never displayed print operand", "print(display({ break 43 }))")
    , ("Never binding operand", "{ break 43 }")
    ]

scalarTransferProgram :: (String, Text) -> (String, Text)
scalarTransferProgram (label, expression) = (label, program
  [ "fn noteInt() -> Int {"
  , "  print(\"integer operand\")"
  , "  return 1"
  , "}"
  , "fn noteBool() -> Bool {"
  , "  print(\"Boolean operand\")"
  , "  return true"
  , "}"
  , "fn take(first: Int, second: Int) -> Int {"
  , "  print(\"callee\")"
  , "  return first + second"
  , "}"
  , "fn main() -> Int {"
  , "  return loop {"
  , "    let skipped = " <> expression
  , "    print(\"after operand\")"
  , "    break 99"
  , "  }"
  , "}"
  ])

controlRefusalPrograms :: [(String, Text)]
controlRefusalPrograms =
  [ ("arithmetic failure in discarded break operand", mainProgram
      [ "  print(\"before break\")"
      , "  loop { break 10 / 0 }"
      , "  return 0"
      ])
  , ("arithmetic failure in no-else value", mainProgram
      [ " let token = if true { 10 / 0 }", " return 0" ])
  , ("arithmetic failure in discarded loop body result", mainProgram
      [ "  var index = 0"
      , "  loop {"
      , "    index = index + 1"
      , "    if index == 2 { break }"
      , "    10 / 0"
      , "  }"
      , "  return 0"
      ])
  ]

mainProgram :: [Text] -> Text
mainProgram body = program (["fn main() -> Int {"] <> body <> ["}"])

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
