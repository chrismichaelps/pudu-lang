{-| @Test.Frontend.ParserExpression.PrimarySpec — literals, lambdas, type arguments, postfixes, and aggregates -}
module Pudu.Frontend.ParserExpression.PrimarySpec
  ( primaryProperties
  , testAggregates
  , testLambdas
  , testLiterals
  , testPostfix
  , testPostfixForms
  , testTypeArguments
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Frontend.ParserExpression.Common
  ( codes
  , firstOf
  , parse
  , validShape
  )
import Pudu.Repl.Outline (outlineExpression)

primaryProperties :: [(String, IO Property)]
primaryProperties =
  [ ("literal vocabulary maps into expression nodes", testLiterals)
  , ("function literals parse in both body forms", testLambdas)
  , ("type arguments are told from an index", testTypeArguments)
  , ("postfix calls and members bind before binary operators", testPostfix)
  , ("index failure-propagation and await postfix forms parse", testPostfixForms)
  , ("tuples and record constructions parse", testAggregates)
  ]

testLiterals :: IO Property
testLiterals = do
  results <- traverse parse ["1", "1.5", "\"hi\"", "'x'", "true", "false", "null"]
  pure (map validShape results === ["1", "1.5", "hi", "x", "true", "false", "null"])

testLambdas :: IO Property
testLambdas = do
  arrow <- parse "fn(x) => x + 1"
  block <- parse "fn(x: Int) -> Int {}"
  empty <- parse "fn() => 1"
  several <- parse "fn(a, b) => a"
  asynchronous <- parse "async fn(x) => x"
  applied <- parse "items.map(fn(x) => x)"
  missingBody <- codes <$> parse "fn(x) x"
  pure $ conjoin
    [ counterexample "an arrow body parses" (validShape arrow === "fn(x)")
    , counterexample "a block body parses" (validShape block === "fn(x)")
    , counterexample "no parameters parses" (validShape empty === "fn()")
    , counterexample "several parameters parse" (validShape several === "fn(a,b)")
    , counterexample "an async literal parses" (validShape asynchronous === "fn(x)")
    , counterexample "a literal is an ordinary argument" (validShape applied === "items.map(fn(x))")
    , counterexample "a missing body names both forms" (missingBody === ["E1032"])
    ]

testTypeArguments :: IO Property
testTypeArguments = do
  applied <- parse "convert[UInt8](value)"
  several <- parse "convert[UInt8, Int](value)"
  byLiteral <- parse "handlers[0](value)"
  byName <- parse "handlers[index](value)"
  plainIndex <- parse "handlers[0]"
  qualified <- parse "Num.small[UInt16](value)"
  notCalled <- parse "handlers[Thing]"
  pure $ conjoin
    [ counterexample "a capitalised name before a call is a type argument"
        (validShape applied === "convert[T](value)")
    , counterexample "several type arguments parse"
        (validShape several === "convert[T,T](value)")
    , counterexample "an index by a literal stays an index"
        (validShape byLiteral === "handlers[0](value)")
    , counterexample "an index by a variable stays an index"
        (validShape byName === "handlers[index](value)")
    , counterexample "an index with no call stays an index"
        (validShape plainIndex === "handlers[0]")
    , counterexample "a qualified name carries type arguments"
        (validShape qualified === "Num.small[T](value)")
    , counterexample "a capitalised index with no call stays an index"
        (validShape notCalled === "handlers[Thing]")
    ]

testPostfix :: IO Property
testPostfix = do
  result <- parse "service.fetch(1, 2,).name + 3"
  pure (validShape result === "(service.fetch(1,2).name+3)")

testPostfixForms :: IO Property
testPostfixForms = do
  index <- parse "a[0]"
  propagation <- parse "read()?"
  awaiting <- parse "fetch().await"
  chained <- parse "rows[i].value?.await"
  pure $ conjoin
    [ validShape index === "a[0]"
    , validShape propagation === "read()?"
    , validShape awaiting === "fetch().await"
    , validShape chained === "rows[i].value?.await"
    ]

testAggregates :: IO Property
testAggregates = do
  tuple <- parse "(1, 2, 3)"
  grouped <- parse "(1 + 2)"
  record <- parse "User{id: 1, name: n}"
  shorthand <- parse "User{id, name}"
  qualified <- parse "Core.User{id: 1}"
  nested <- parse "Wrapper{inner: User{id: 2}}"
  blockNotRecord <- parse "if READY {} else {}"
  parenthesized <- parse "if (User{id: 1}).id > 0 {} else {}"
  setLiteral <- parse "#{3, 1, 2, 1,}"
  emptySet <- parse "#{}"
  recordMember <- parse "#{User{id: 1}}"
  pure $ conjoin
    [ validShape tuple === "(1,2,3)"
    , counterexample "one member without a comma groups" (validShape grouped === "(1+2)")
    , validShape record === "User{id:1,name:n}"
    , counterexample "a field without a value is shorthand"
        (validShape shorthand === "User{id,name}")
    , validShape qualified === "Core.User{id:1}"
    , validShape nested === "Wrapper{inner:User{id:2}}"
    , counterexample "a condition keeps its block"
        (validShape blockNotRecord === "if")
    , counterexample "parentheses reinstate a record construction"
        (validShape parenthesized === "if")
    , counterexample "a Set retains written members and a trailing comma"
        (validShape setLiteral === "#{3,1,2,1}")
    , counterexample "the REPL outline retains written Set order"
        (outlineExpression (firstOf setLiteral) === "#{3, 1, 2, 1}")
    , counterexample "an empty Set is a distinct aggregate"
        (validShape emptySet === "#{}")
    , counterexample "records are admitted inside a Set literal"
        (validShape recordMember === "#{User{id:1}}")
    ]
