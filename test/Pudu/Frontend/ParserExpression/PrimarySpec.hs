{-| @Test.Frontend.ParserExpression.PrimarySpec — literals, lambdas, type arguments, postfixes, and aggregates -}
module Pudu.Frontend.ParserExpression.PrimarySpec
  ( primaryProperties
  , testAggregates
  , testLambdas
  , testRanges
  , testShortLambdas
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
  , ("the short function literal parses in every form", testShortLambdas)
  , ("ranges parse with either end, both, or neither", testRanges)
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

{-| The short literal, `|x| body`.

    It builds the same node the long form builds, which is why every case here
    reads back as `fn(...)`: the two spellings are one value, and nothing after
    the parser can tell which was written. -}
testShortLambdas :: IO Property
testShortLambdas = do
  single <- parse "|x| x + 1"
  several <- parse "|a, b| a"
  annotated <- parse "|x: Int| x"
  resultType <- parse "|x| -> Int { x }"
  empty <- parse "|| 1"
  block <- parse "|x| { x }"
  nested <- parse "|a| |b| a"
  applied <- parse "items.map(|x| x)"
  asynchronous <- parse "async |x| x"
  binaryStillJoins <- parse "a | b"
  pure $ conjoin
    [ counterexample "one parameter parses" (validShape single === "fn(x)")
    , counterexample "several parameters parse" (validShape several === "fn(a,b)")
    , counterexample "an annotated parameter parses" (validShape annotated === "fn(x)")
    , counterexample "a result type parses" (validShape resultType === "fn(x)")
    , counterexample "no parameters is spelled with the joined bars"
        (validShape empty === "fn()")
    , counterexample "a block body parses" (validShape block === "fn(x)")
    , counterexample "a literal may answer with a literal" (validShape nested === "fn(a)")
    , counterexample "a literal is an ordinary argument"
        (validShape applied === "items.map(fn(x))")
    , counterexample "an async short literal parses" (validShape asynchronous === "fn(x)")
    , counterexample "a bar between two values still joins them"
        (validShape binaryStillJoins === "(a|b)")
    ]

{-| A range, which may be written with either end left off.

    An absent end is answered by whatever the range is applied to, so the
    parser has to admit a range that names only one of its ends — and has to
    tell `items[2..]`, where the bracket ends the range, from `2..n`, where the
    name is its end. -}
testRanges :: IO Property
testRanges = do
  both <- parse "1..4"
  inclusive <- parse "1..=4"
  openUpper <- parse "items[2..]"
  openLower <- parse "items[..2]"
  openBoth <- parse "items[..]"
  computed <- parse "start..stop + 1"
  compared <- parse "n in 0..4"
  chained <- codes <$> parse "1..2..3"
  openInclusive <- codes <$> parse "items[1..=]"
  pure $ conjoin
    [ counterexample "both ends parse" (validShape both === "(1..4)")
    , counterexample "an inclusive range keeps its spelling"
        (validShape inclusive === "(1..=4)")
    , counterexample "a bracket ends a range with no upper end"
        (validShape openUpper === "items[(2..)]")
    , counterexample "a range may name only its upper end"
        (validShape openLower === "items[(..2)]")
    , counterexample "a range may name neither end" (validShape openBoth === "items[(..)]")
    , counterexample "a range binds looser than addition"
        (validShape computed === "(start..(stop+1))")
    , counterexample "a range binds tighter than comparison"
        (validShape compared === "(nin(0..4))")
    , counterexample "a range cannot be chained" (chained === ["E1062"])
    , counterexample "an inclusive range names the value it includes"
        (openInclusive === ["E1063"])
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
