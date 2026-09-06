{-| @Test.Repl.Session.EvaluationSpec — interactive evaluation, loops, traits, and error handling -}
module Pudu.Repl.Session.EvaluationSpec
  ( evaluationProperties
  , testControlTransfer
  , testInteractiveLocation
  , testIteration
  , testIterationEdges
  , testLoadedOffsets
  , testMatch
  , testOperators
  , testRecursionAndReturn
  , testRuntimeErrors
  , testStaticTypeInspection
  , testTraits
  ) where

import qualified Data.Text as Text
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

import Pudu.Diagnostic.Render
  ( RenderStyle (PlainStyle)
  , interactiveRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Repl.Session
  ( EntryResult (..)
  , contextSummary
  , emptySession
  , inspectEntryType
  , typeOfEntry
  )
import Pudu.Repl.Session.Common
  ( codeOf
  , codesOf
  , headName
  , loadFixture
  , submit
  , valueOf
  )
import Pudu.Type (renderType)

evaluationProperties :: [(String, IO Property)]
evaluationProperties =
  [ ("diagnostics are reported against the typed line", testInteractiveLocation)
  , ("type inspection stops before evaluation", testStaticTypeInspection)
  , ("a loaded file does not shift where the entry sits", testLoadedOffsets)
  , ("loops and iteration evaluate in the interactive session", testIteration)
  , ("trait methods dispatch and inherit in the session", testTraits)
  , ("runtime errors surface and leave the session unchanged", testRuntimeErrors)
  , ("recursion and return interact with loops", testRecursionAndReturn)
  , ("control transfers are confined to their owning construct", testControlTransfer)
  , ("iteration edge cases are handled correctly", testIterationEdges)
  , ("operators short-circuit and index correctly", testOperators)
  , ("match expressions bind and guard correctly", testMatch)
  ]

testLoadedOffsets :: IO Property
testLoadedOffsets = do
  loaded <- loadFixture
  textType <- typeOfEntry loaded "\"hello\""
  arrayType <- typeOfEntry loaded "[1, 2]"
  functionType <- typeOfEntry loaded "twice"
  constType <- typeOfEntry loaded "LIMIT"
  bareText <- typeOfEntry emptySession "\"hello\""
  pure $ conjoin
    [ counterexample "text is text with a file loaded" (fmap headName textType === Just "Str")
    , counterexample "an array is an array" (fmap headName arrayType === Just "Array")
    , counterexample "a loaded function keeps its type"
        (fmap renderType functionType === Just "fn(Int) -> Int")
    , counterexample "a loaded constant keeps its type"
        (fmap headName constType === Just "Int")
    , counterexample "and a loaded file changes none of it"
        (fmap headName textType === fmap headName bareText)
    ]

testStaticTypeInspection :: IO Property
testStaticTypeInspection = do
  (_, _, diagnostics, found) <- inspectEntryType emptySession "1 / 0"
  (_, _, broken, missing) <- inspectEntryType emptySession "notInScope"
  (_, _, statementDiagnostics, statementType) <-
    inspectEntryType emptySession "let held = 1"
  pure $ conjoin
    [ counterexample "a runtime failure still has a static type"
        (diagnostics === [])
    , fmap renderType found === Just "Int"
    , counterexample "compiler failures remain visible"
        (map codeOf broken === ["E2010"])
    , missing === Nothing
    , counterexample "a statement type-checks but has no expression type"
        (statementDiagnostics === [])
    , statementType === Nothing
    ]

testInteractiveLocation :: IO Property
testInteractiveLocation = do
  result <- submit emptySession "missing + 1"
  let config = interactiveRenderConfig PlainStyle "<interactive>" (resultFirstLine result)
      rendered = renderDiagnosticsWith config (resultSource result) (resultDiagnostics result)
  pure $ conjoin
    [ counterexample (Text.unpack rendered)
        (property (Text.isInfixOf "<interactive>:1:1" rendered))
    , counterexample "the typed line is quoted"
        (property (Text.isInfixOf "missing + 1" rendered))
    , renderSummary (resultDiagnostics result) === "1 error"
    ]

testIteration :: IO Property
testIteration = do
  whileSetup <- submit emptySession "var total = 0"
  whileLoop <- submit (resultSession whileSetup) "while total < 3 {\n  total = total + 1\n}"
  whileResult <- submit (resultSession whileLoop) "total"

  loopSetup <- submit emptySession "var n = 0"
  loopBody <- submit (resultSession loopSetup) "loop {\n  if n == 5 { break }\n  n = n + 1\n}"
  loopResult <- submit (resultSession loopBody) "n"

  forSetup <- submit emptySession "var sum = 0"
  forIter <- submit (resultSession forSetup) "for x in (1, 2, 3) {\n  sum = sum + x\n}"
  forResult <- submit (resultSession forIter) "sum"

  continueSetup <- submit emptySession "var kept = 0\nvar i = 0"
  continueLoop <- submit (resultSession continueSetup) "while i < 5 {\n  i = i + 1\n  if i == 2 { continue }\n  kept = kept + 1\n}"
  continueResult <- submit (resultSession continueLoop) "kept"

  forStringSetup <- submit emptySession "var chars = 0"
  forString <- submit (resultSession forStringSetup) "for c in \"abc\" {\n  chars = chars + 1\n}"
  forStringResult <- submit (resultSession forString) "chars"

  persisted <- submit (resultSession whileLoop) "total"

  pure $ conjoin
    [ counterexample "a while loop accumulates across iterations" (valueOf whileResult === "3")
    , counterexample "a loop breaks on condition" (valueOf loopResult === "5")
    , counterexample "for iterates a tuple's elements" (valueOf forResult === "6")
    , counterexample "continue skips an iteration body" (valueOf continueResult === "4")
    , counterexample "for iterates a string's characters" (valueOf forStringResult === "3")
    , counterexample "the mutated binding persists after the loop" (valueOf persisted === "3")
    ]

testTraits :: IO Property
testTraits = do
  typeRecord <- submit emptySession "type User = { name: Str }"
  traitDecl <- submit (resultSession typeRecord) "trait Greet {\n  fn name(self: &Self) -> Str\n  fn greet(self: &Self) -> Str = \"hello\"\n}"
  implDecl <- submit (resultSession traitDecl) "impl Greet for User {\n  fn name(self: &Self) -> Str { self.name }\n}"
  methodName <- submit (resultSession implDecl) "User{name: \"ada\"}.name()"
  methodGreet <- submit (resultSession implDecl) "User{name: \"ada\"}.greet()"
  showTrait <- submit (resultSession implDecl) "trait Show {\n  fn show(self: &Self) -> Str\n}"
  showImpl <- submit (resultSession showTrait) "impl Show for User {\n  fn show(self: &Self) -> Str { self.name }\n}"
  boundFn <- submit (resultSession showImpl) "fn display[T: Show](value: T) -> Str { value.show() }"
  called <- submit (resultSession boundFn) "display(User{name: \"ada\"})"
  unbounded <- submit (resultSession boundFn) "display(5)"
  persisted <- submit (resultSession implDecl) "User{name: \"ada\"}.greet()"
  pure $ conjoin
    [ counterexample "a type and trait are declared in the session" (resultAccepted typeRecord && resultAccepted traitDecl)
    , counterexample "an impl is declared in the session" (resultAccepted implDecl)
    , counterexample "a method dispatches on the receiver type" (valueOf methodName === "\"ada\"")
    , counterexample "a default is inherited from the trait" (valueOf methodGreet === "\"hello\"")
    , counterexample "a bounded generic function is declared" (resultAccepted boundFn)
    , counterexample "the bound is satisfied at the call site" (valueOf called === "\"ada\"")
    , counterexample "a type without the implementation is rejected" (codesOf unbounded === ["E3012"])
    , counterexample "the inherited default persists across entries" (valueOf persisted === "\"hello\"")
    ]

testRuntimeErrors :: IO Property
testRuntimeErrors = do
  divZero <- submit emptySession "1 / 0"
  divZeroStmt <- submit emptySession "let x = 1 / 0"
  indexRange <- submit emptySession "[1, 2, 3][5]"
  undefinedName <- submit emptySession "missing + 1"
  nonExhaustive <- submit emptySession "match 5 {\n  case 0 => 0\n}"
  typeMismatch <- submit emptySession "1 + \"a\""
  after <- submit (resultSession divZeroStmt) "1 + 2"
  pure $ conjoin
    [ counterexample "division by zero is E7004" (codesOf divZero === ["E7004"])
    , counterexample "a runtime error rejects the entry" (not (resultAccepted divZeroStmt))
    , counterexample "an array index out of range is E7004" (codesOf indexRange === ["E7004"])
    , counterexample "an undefined name is E2010" (codesOf undefinedName === ["E2010"])
    , counterexample "a non-exhaustive match is E5001" (codesOf nonExhaustive === ["E5001"])
    , counterexample "a type mismatch is E3001" (codesOf typeMismatch === ["E3001"])
    , counterexample "a rejected runtime entry leaves the session unchanged"
        (length (contextSummary (resultSession divZeroStmt)) === 0)
    , counterexample "the session still works after a runtime error" (valueOf after === "3")
    ]

testRecursionAndReturn :: IO Property
testRecursionAndReturn = do
  factDecl <- submit emptySession "fn fact(n: Int) -> Int {\n  if n <= 1 { return 1 }\n  n * fact(n - 1)\n}"
  factCall <- submit (resultSession factDecl) "fact(5)"
  earlyReturn <- submit emptySession "fn early() -> Int {\n  return 42\n  99\n}"
  earlyCall <- submit (resultSession earlyReturn) "early()"
  returnInLoop <- submit emptySession "fn find(target: Int) -> Int {\n  var i = 0\n  while i < 1000 {\n    if i == target { return i }\n    i = i + 1\n  }\n  0\n}"
  found <- submit (resultSession returnInLoop) "find(7)"
  pure $ conjoin
    [ counterexample "recursion computes factorial" (valueOf factCall === "120")
    , counterexample "return exits before the trailing expression" (valueOf earlyCall === "42")
    , counterexample "return escapes the loop and the function" (valueOf found === "7")
    ]

testControlTransfer :: IO Property
testControlTransfer = do
  nestedSetup <- submit emptySession "var outer = 0"
  nestedLoop <- submit (resultSession nestedSetup) "var inner = 0\nloop {\n  outer = outer + 1\n  if outer > 3 { break }\n  loop {\n    inner = inner + 1\n    if inner >= 2 { break }\n  }\n}"
  nestedOuter <- submit (resultSession nestedLoop) "outer"
  nestedInner <- submit (resultSession nestedLoop) "inner"

  breakSetup <- submit emptySession "var hit = 0"
  breakLoop <- submit (resultSession breakSetup) "for x in (1, 2, 3, 4, 5) {\n  if x == 3 { break }\n  hit = hit + 1\n}"
  breakResult <- submit (resultSession breakLoop) "hit"

  continueSetup <- submit emptySession "var collected = 0"
  continueLoop <- submit (resultSession continueSetup) "for x in (1, 2, 3) {\n  if x == 2 { continue }\n  collected = collected + x\n}"
  continueResult <- submit (resultSession continueLoop) "collected"

  breakOutside <- submit emptySession "fn bad() -> Int {\n  break\n  1\n}"

  labelledSetup <- submit emptySession "var seen = 0"
  labelledLoop <- submit (resultSession labelledSetup) "@outer for row in ((1, 2), (3, 4)) {\n  for cell in row {\n    if cell == 3 { break @outer }\n    seen = seen + 1\n  }\n}"
  labelledResult <- submit (resultSession labelledLoop) "seen"

  carriedSetup <- submit emptySession "let carried = loop { break 7 }"
  carried <- submit (resultSession carriedSetup) "carried"
  carriedLabelSetup <- submit emptySession "let found = @search loop {\n  loop { break @search 9 }\n}"
  carriedLabel <- submit (resultSession carriedLabelSetup) "found"

  closureBreak <- submit emptySession "fn outerLoop() -> Int {\n  loop {\n    let f = fn() -> Int { break\n 1 }\n    break 0\n  }\n}"
  unknownLabel <- submit emptySession "loop { break @missing }"
  carriedFromFor <- submit emptySession "for x in (1, 2) { break x }"
  pure $ conjoin
    [ counterexample "break exits only the inner loop" (valueOf nestedOuter === "4")
    , counterexample "the inner loop accumulates across outer iterations" (valueOf nestedInner === "4")
    , counterexample "break in for stops iteration" (valueOf breakResult === "2")
    , counterexample "continue in for skips one element" (valueOf continueResult === "4")
    , counterexample "break outside a loop is caught before it runs"
        (codesOf breakOutside === ["E2016"])
    , counterexample "a labelled break leaves the loop it names"
        (valueOf labelledResult === "2")
    , counterexample "a loop produces what its break carries" (valueOf carried === "7")
    , counterexample "a labelled break carries a value out of nested loops"
        (valueOf carriedLabel === "9")
    , counterexample "a closure is not inside the loop that defines it"
        (codesOf closureBreak === ["E2016"])
    , counterexample "a label naming no enclosing loop is rejected"
        (codesOf unknownLabel === ["E2017"])
    , counterexample "a for loop cannot carry a value out"
        (codesOf carriedFromFor === ["E3029"])
    ]

testIterationEdges :: IO Property
testIterationEdges = do
  emptyTupleSetup <- submit emptySession "var count = 0"
  emptyTupleLoop <- submit (resultSession emptyTupleSetup) "for x in () {\n  count = count + 1\n}"
  emptyTupleResult <- submit (resultSession emptyTupleLoop) "count"

  emptyStringSetup <- submit emptySession "var count = 0"
  emptyStringLoop <- submit (resultSession emptyStringSetup) "for c in \"\" {\n  count = count + 1\n}"
  emptyStringResult <- submit (resultSession emptyStringLoop) "count"

  breakSetup <- submit emptySession "var ran = 0"
  breakLoop <- submit (resultSession breakSetup) "loop {\n  break\n  ran = ran + 1\n}"
  breakResult <- submit (resultSession breakLoop) "ran"

  whileFalseSetup <- submit emptySession "var ran = 0"
  whileFalseLoop <- submit (resultSession whileFalseSetup) "while false {\n  ran = ran + 1\n}"
  whileFalseResult <- submit (resultSession whileFalseLoop) "ran"

  nestedWhileSetup <- submit emptySession "var total = 0\nvar i = 0"
  nestedWhileLoop <- submit (resultSession nestedWhileSetup) "while i < 3 {\n  var j = 0\n  while j < 3 {\n    total = total + 1\n    j = j + 1\n  }\n  i = i + 1\n}"
  nestedWhileResult <- submit (resultSession nestedWhileLoop) "total"

  forInForSetup <- submit emptySession "var total = 0"
  forInForLoop <- submit (resultSession forInForSetup) "for a in (1, 2) {\n  for b in (3, 4) {\n    total = total + a + b\n  }\n}"
  forInForResult <- submit (resultSession forInForLoop) "total"

  pure $ conjoin
    [ counterexample "iterating an empty tuple runs zero times" (valueOf emptyTupleResult === "0")
    , counterexample "iterating an empty string runs zero times" (valueOf emptyStringResult === "0")
    , counterexample "break before the body skips it" (valueOf breakResult === "0")
    , counterexample "a false while condition never enters" (valueOf whileFalseResult === "0")
    , counterexample "nested while loops multiply" (valueOf nestedWhileResult === "9")
    , counterexample "nested for loops iterate the product" (valueOf forInForResult === "20")
    ]

testOperators :: IO Property
testOperators = do
  andShort <- submit emptySession "false && (1 / 0 == 0)"
  orShort <- submit emptySession "true || (1 / 0 == 0)"
  tupleIndex <- submit emptySession "(10, 20, 30)[1]"
  stringIndex <- submit emptySession "\"hello\"[1]"
  negativeIndex <- submit emptySession "[1, 2, 3][-1]"
  outOfRange <- submit emptySession "[1, 2][10]"
  stringConcat <- submit emptySession "\"foo\" + \"bar\""
  unaryNeg <- submit emptySession "-42"
  unaryNot <- submit emptySession "!false"
  rangeExpr <- submit emptySession "1..4"
  pure $ conjoin
    [ counterexample "&& short-circuits without evaluating the right" (valueOf andShort === "false")
    , counterexample "|| short-circuits without evaluating the right" (valueOf orShort === "true")
    , counterexample "tuple indexing reads the element" (valueOf tupleIndex === "20")
    , counterexample "string indexing reads the character" (valueOf stringIndex === "'e'")
    , counterexample "a negative index is E7004" (codesOf negativeIndex === ["E7004"])
    , counterexample "an out-of-range index is E7004" (codesOf outOfRange === ["E7004"])
    , counterexample "string concatenation joins" (valueOf stringConcat === "\"foobar\"")
    , counterexample "unary negation works" (valueOf unaryNeg === "-42")
    , counterexample "unary not works" (valueOf unaryNot === "true")
    , counterexample "range produces a tuple" (valueOf rangeExpr === "(1, 2, 3)")
    ]

testMatch :: IO Property
testMatch = do
  literalMatch <- submit emptySession "match 2 {\n  case 1 => \"one\"\n  case 2 => \"two\"\n  case _ => \"other\"\n}"
  wildcardMatch <- submit emptySession "match 99 {\n  case 1 => \"one\"\n  case _ => \"other\"\n}"
  guardMatch <- submit emptySession "match 5 {\n  case n if n > 3 => \"big\"\n  case _ => \"small\"\n}"
  guardFalse <- submit emptySession "match 2 {\n  case n if n > 3 => \"big\"\n  case _ => \"small\"\n}"
  bindingMatch <- submit emptySession "match 42 {\n  case x => x\n}"
  tuplePattern <- submit emptySession "match (1, 2) {\n  case (a, b) => a + b\n}"
  rangePattern <- submit emptySession "match 5 {\n  case 1..=3 => \"low\"\n  case 4..=6 => \"mid\"\n  case _ => \"high\"\n}"
  pure $ conjoin
    [ counterexample "a literal arm is selected" (valueOf literalMatch === "\"two\"")
    , counterexample "a wildcard arm catches anything" (valueOf wildcardMatch === "\"other\"")
    , counterexample "a guard selects a matching arm" (valueOf guardMatch === "\"big\"")
    , counterexample "a false guard falls through" (valueOf guardFalse === "\"small\"")
    , counterexample "a binding arm captures the value" (valueOf bindingMatch === "42")
    , counterexample "a tuple pattern destructures" (valueOf tuplePattern === "3")
    , counterexample "a range pattern matches inclusively" (valueOf rangePattern === "\"mid\"")
    ]
