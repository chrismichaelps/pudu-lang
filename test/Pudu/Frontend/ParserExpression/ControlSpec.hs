{-| @Test.Frontend.ParserExpression.ControlSpec — unary, conditional, if-let, loop, for, and match expressions -}
module Pudu.Frontend.ParserExpression.ControlSpec
  ( controlProperties
  , testControlExpressions
  , testControlRecovery
  , testIfLet
  , testUnaryIf
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Frontend.ParserExpression.Common
  ( codes
  , diagnosticOffsets
  , firstOf
  , helps
  , parse
  , remainingOf
  , shape
  , validShape
  )
import Pudu.Frontend.Token (TokenKind (..))
import Pudu.Repl.Outline (outlineExpression)

controlProperties :: [(String, IO Property)]
controlProperties =
  [ ("unary borrow and conditional blocks preserve structure", testUnaryIf)
  , ("if let binds one refutable pattern", testIfLet)
  , ("match while loop and for parse as expressions", testControlExpressions)
  , ("control owners survive mixed-chain recovery", testControlRecovery)
  ]

testUnaryIf :: IO Property
testUnaryIf = do
  unary <- parse "&mut -value"
  conditional <- parse "if true {} else if false {} else {}"
  pure $ conjoin
    [ validShape unary === "(&mut(-value))"
    , validShape conditional === "if"
    ]

testIfLet :: IO Property
testIfLet = do
  present <- parse "if let Some(value) = candidate {} else {}"
  absentElse <- parse "if let Some(value) = candidate {}"
  chained <- parse
    "if let Some(first) = left {} else if let Some(second) = right {} else {}"
  irrefutable <- traverse parse
    [ "if let value = candidate {}"
    , "if let _ = candidate {}"
    , "if let (first, second) = pair {}"
    , "if let {value} = record {}"
    , "if let _ | Some(value) = candidate {}"
    ]
  missingPattern <- parse "if let = candidate {}"
  missingEquals <- parse "if let Some(value) candidate {}"
  pure $ conjoin
    [ counterexample "the surface node retains pattern subject and else"
        (validShape present === "if let Some(value) = candidate else")
    , counterexample "else remains optional"
        (validShape absentElse === "if let Some(value) = candidate")
    , counterexample "else if let nests as a conditional chain"
        (validShape chained === "if let Some(first) = left else")
    , counterexample ":ast retains if let rather than inventing match"
        (outlineExpression (firstOf present) === "if let Some(value) = candidate else ...")
    , counterexample "syntactically irrefutable patterns are rejected"
        (map codes irrefutable === replicate 5 ["E1056"])
    , counterexample "E1056 points at the pattern"
        (map diagnosticOffsets irrefutable === [[7], [7], [7], [7], [7]])
    , counterexample "E1056 explains the unconditional form"
        ( map helps irrefutable
          === replicate 5
            ["use let for an unconditional binding, or choose a pattern that can fail"]
        )
    , counterexample "a missing pattern preserves the owned equals"
        (codes missingPattern === ["E1050"])
    , counterexample "a missing equals is owned once"
        (codes missingEquals === ["E1001"])
    ]

testControlExpressions :: IO Property
testControlExpressions = do
  matched <- parse "match value {\n  case Ok(v) if v > 0 => v\n  case _ => 0\n}"
  loopValue <- parse "loop {}"
  whileValue <- parse "while ready {}"
  forValue <- parse "for item in items {}"
  labelledLoop <- parse "@retry loop {}"
  labelledWhile <- parse "@outer while ready {}"
  labelledFor <- parse "@rows for item in items {}"
  strayLabel <- parse "@rows item"
  pure $ conjoin
    [ validShape matched === "match(value){Ok(v) if (v>0)=>v;_=>0}"
    , validShape loopValue === "loop"
    , validShape whileValue === "while(ready)"
    , validShape forValue === "for item in items"
    , counterexample "a label attaches to the loop that follows it"
        (validShape labelledLoop === "@retry loop")
    , validShape labelledWhile === "@outer while(ready)"
    , validShape labelledFor === "@rows for item in items"
    , counterexample "a label naming no loop is rejected where it was written"
        (codes strayLabel === ["E1053"])
    ]

testControlRecovery :: IO Property
testControlRecovery = do
  condition <- parse "if a\n+ b\n- c {} else {}"
  whileCondition <- parse "while a\n+ b\n- c {}"
  forIterable <- parse "for x in a\n+ b\n- c {}"
  matchScrutinee <- parse "match a\n+ b\n- c { case _ => 0 }"
  matchGuard <- parse
    "match value {\ncase x if a\n+ b\n- c => 1\ncase _ => 0\n}"
  matchBody <- parse
    "match value {\ncase 0 => a\n+ b\n- c\ncase _ => 0\n}"
  repeated <- parse "if a\n+ b\n- c\n& d\n* e {}"
  let recovered =
        [ condition, whileCondition, forIterable, matchScrutinee, matchGuard, matchBody, repeated ]
  pure $ conjoin
    [ counterexample "every control ambiguity is diagnosed exactly once"
        (map codes recovered === replicate 7 ["E1055"])
    , counterexample "every control owner completes its enclosing expression"
        (map remainingOf recovered === replicate 7 EndOfFile)
    , counterexample "if, while, for, and match structure survives recovery"
        ( map (shape . firstOf) recovered
          === [ "if"
              , "while((a+b))"
              , "for x in (a+b)"
              , "match((a+b)){_=>0}"
              , "match(value){x if (a+b)=>1;_=>0}"
              , "match(value){0=>(a+b);_=>0}"
              , "if"
              ]
        )
    ]
