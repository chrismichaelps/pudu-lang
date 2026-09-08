{-| @Test.Repl.Session.ContextSpec — environment persistence, inspection, kinds, describe, and imports -}
module Pudu.Repl.Session.ContextSpec
  ( contextProperties
  , testDescribe
  , testHigherKindedInspection
  , testHotRedefinition
  , testInspection
  , testInteractiveImports
  , testKinds
  , testPersistence
  , testRejection
  ) where

import qualified Data.Text as Text
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

import Pudu.Repl.Describe
  ( declarationSummary
  , describeInstances
  , describeKindLines
  , describeName
  )
import Pudu.Repl.Session
  ( EntryKind (..)
  , EntryResult (..)
  , contextSummary
  , emptySession
  , inspectContext
  , inspectSession
  , sessionExports
  )
import Pudu.Repl.Session.Common (codeOf, codesOf, feed, submit, valueOf)

contextProperties :: [(String, IO Property)]
contextProperties =
  [ ("bindings and declarations persist across entries", testPersistence)
  , ("a rejected entry leaves the session unchanged", testRejection)
  , ("inspection reports the session context without changing it", testInspection)
  , ("describing a name reports how the session declared it", testDescribe)
  , ("kinds report declared arity", testKinds)
  , ("inspection preserves higher-kinded parameter arity", testHigherKindedInspection)
  , ("an imported module is reachable at the prompt", testInteractiveImports)
  , ("redefined bindings and declarations replace in place without collision", testHotRedefinition)
  ]

testInteractiveImports :: IO Property
testInteractiveImports = do
  imported <- submit emptySession "import Std.Math as M"
  used <- submit (resultSession imported) "M.factorial(4)"

  decimalImport <- submit emptySession "import Std.Decimal as D"
  decimalUse <- submit (resultSession decimalImport) "D.rescale(1.239d, 2)"

  missing <- submit emptySession "import Std.NotAModule as X"
  pure $ conjoin
    [ counterexample "the import itself is accepted"
        (property (resultAccepted imported))
    , counterexample "an imported function is reachable and linked"
        (valueOf used === "24")
    , counterexample "the decimal module works the same way"
        (valueOf decimalUse === "1.24")
    , counterexample "a module that is nowhere is reported"
        (codesOf missing === ["E2014"])
    ]

testPersistence :: IO Property
testPersistence = do
  first <- submit emptySession "let base = 10"
  second <- submit (resultSession first) "fn twice(n: Int) -> Int { n * 2 }"
  third <- submit (resultSession second) "twice(base)"
  expressionForgotten <- submit (resultSession third) "base"
  mutVar <- submit emptySession "var counter = 0"
  mutAssign1 <- submit (resultSession mutVar) "counter = counter + 1"
  mutVal1 <- submit (resultSession mutAssign1) "counter"
  mutAssign2 <- submit (resultSession mutVal1) "counter = counter + 10"
  mutVal2 <- submit (resultSession mutAssign2) "counter"
  pure $ conjoin
    [ counterexample "the binding is used by a later entry" (valueOf third === "20")
    , counterexample "an expression adds nothing to the context"
        (length (contextSummary (resultSession third)) === 2)
    , valueOf expressionForgotten === "10"
    , counterexample "assignment statement kind is StatementEntry"
        (resultKind mutAssign1 === StatementEntry)
    , counterexample "assignment produces no value output"
        (valueOf mutAssign1 === "none")
    , counterexample "variable mutation persists across entries"
        (valueOf mutVal1 === "1")
    , counterexample "subsequent mutation accumulates correctly"
        (valueOf mutVal2 === "11")
    ]

testRejection :: IO Property
testRejection = do
  accepted <- submit emptySession "let kept = 1"
  rejected <- submit (resultSession accepted) "let broken = missing"
  after <- submit (resultSession rejected) "kept"
  letTyped <- submit emptySession "let target = 1"
  rejectedTypeMismatch <- submit (resultSession letTyped) "target = \"mismatch\""
  afterMismatch <- submit (resultSession rejectedTypeMismatch) "target"
  rejectedUndeclared <- submit emptySession "missing_var = 10"
  pure $ conjoin
    [ counterexample "the failed entry is not accepted" (property (not (resultAccepted rejected)))
    , codesOf rejected === ["E2010"]
    , counterexample "the session is unchanged"
        (contextSummary (resultSession rejected) === contextSummary (resultSession accepted))
    , counterexample "earlier work still evaluates" (valueOf after === "1")
    , counterexample "assignment with type mismatch is rejected"
        (property (not (resultAccepted rejectedTypeMismatch)))
    , counterexample "assignment error leaves target binding unchanged"
        (valueOf afterMismatch === "1")
    , counterexample "assignment to undeclared variable is rejected"
        (property (not (resultAccepted rejectedUndeclared)))
    ]

testInspection :: IO Property
testInspection = do
  first <- submit emptySession "export fn shown() -> Int { 1 }"
  (resolution, diagnostics) <- inspectSession (resultSession first)
  after <- submit (resultSession first) "shown()"
  pure $ conjoin
    [ counterexample "inspection is clean" (map codeOf diagnostics === [])
    , maybe [] sessionExports resolution === ["shown"]
    , counterexample "inspection did not disturb the session" (valueOf after === "1")
    ]

testDescribe :: IO Property
testDescribe = do
  session <- feed emptySession
    [ "type Point = { x: Int, y: Int }"
    , "trait Show { fn show(self: &Self) -> Str }"
    , "impl Show for Point { fn show(self: &Self) -> Str { \"p\" } }"
    ]
  (_, parsed, _) <- inspectContext session
  pure $ case parsed of
    Nothing -> counterexample "the session parsed" (property False)
    Just moduleValue ->
      conjoin
        [ counterexample
            "info reports the record declaration"
            (any (Text.isInfixOf "type Point") (describeName moduleValue "Point"))
        , counterexample
            "info reports the trait member"
            (any (Text.isInfixOf "fn show") (describeName moduleValue "Show"))
        , counterexample
            "instances report the implementation"
            (describeInstances moduleValue "Point" === ["impl Show for Point"])
        , counterexample
            "an unknown name describes as nothing"
            (describeName moduleValue "Missing" === [])
        , counterexample
            "the summary lists declarations without the session wrapper"
            (filter (Text.isPrefixOf "fn __") (declarationSummary moduleValue) === [])
        ]

testKinds :: IO Property
testKinds = do
  session <- feed emptySession ["type Pair[A, B] = { left: A, right: B }"]
  (_, parsed, _) <- inspectContext session
  pure $ case parsed of
    Nothing -> counterexample "the session parsed" (property False)
    Just moduleValue ->
      conjoin
        [ counterexample
            "a declared constructor reports its parameters"
            (describeKindLines moduleValue "Pair" === ["Pair :: type -> type -> type"])
        , counterexample
            "a wired-in constructor reports its parameters"
            (describeKindLines moduleValue "Option" === ["Option :: type -> type"])
        , counterexample
            "a scalar is a plain type"
            (describeKindLines moduleValue "Int" === ["Int :: type"])
        , counterexample
            "an unknown type says so"
            (describeKindLines moduleValue "Nope" === ["not in scope: type 'Nope'"])
        ]

testHigherKindedInspection :: IO Property
testHigherKindedInspection = do
  session <-
    feed
      emptySession
      [ "trait Higher[F[_]] {}"
      , "trait Two[F[_, _]] {}"
      , "trait Mixed[A, F[_], B] {}"
      , "type Pair[A, B] = { left: A, right: B }"
      ]
  (_, parsed, _) <- inspectContext session
  pure $ case parsed of
    Nothing -> counterexample "the session parsed" (property False)
    Just moduleValue ->
      conjoin
        [ counterexample
            "a unary constructor parameter keeps its hole"
            (any (Text.isInfixOf "Higher[F[_]]") (describeName moduleValue "Higher") === True)
        , counterexample
            "a binary constructor parameter keeps both holes"
            (any (Text.isInfixOf "Two[F[_, _]]") (describeName moduleValue "Two") === True)
        , counterexample
            "ordinary and constructor parameters render in declaration order"
            (any (Text.isInfixOf "Mixed[A, F[_], B]") (describeName moduleValue "Mixed") === True)
        , counterexample
            "a kind parenthesises the constructor it accepts"
            (describeKindLines moduleValue "Higher" === ["Higher :: (type -> type) -> type"])
        , counterexample
            "a binary constructor parameter is one input, not two"
            (describeKindLines moduleValue "Two" === ["Two :: (type -> type -> type) -> type"])
        , counterexample
            "a mixed declaration keeps each parameter's own shape"
            ( describeKindLines moduleValue "Mixed"
                === ["Mixed :: type -> (type -> type) -> type -> type"]
            )
        , counterexample
            "a first-order declaration is unchanged"
            (describeKindLines moduleValue "Pair" === ["Pair :: type -> type -> type"])
        , counterexample
            "an ordinary parameter carries no holes"
            (any (Text.isInfixOf "Pair[A, B]") (describeName moduleValue "Pair") === True)
        ]

testHotRedefinition :: IO Property
testHotRedefinition = do
  fn1 <- submit emptySession "fn add(a: Int, b: Int) -> Int { a + b }"
  res1 <- submit (resultSession fn1) "add(2, 3)"
  fn2 <- submit (resultSession res1) "fn add(a: Int, b: Int) -> Int { a + b + 10 }"
  res2 <- submit (resultSession fn2) "add(2, 3)"
  let1 <- submit (resultSession res2) "let x = 10"
  let2 <- submit (resultSession let1) "let x = 42"
  resX <- submit (resultSession let2) "x"
  pure $ conjoin
    [ counterexample "initial function evaluates" (valueOf res1 === "5")
    , counterexample "redefined function replaces in place and evaluates" (valueOf res2 === "15")
    , counterexample "context only has one add declaration"
        (length (filter (Text.isInfixOf "add") (contextSummary (resultSession fn2))) === 1)
    , counterexample "redefined let binding replaces in place and evaluates" (valueOf resX === "42")
    , counterexample "context only has one x binding"
        (length (filter (Text.isInfixOf "x") (contextSummary (resultSession let2))) === 1)
    ]
