module Pudu.Repl.SessionSpec (replProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText)
import Pudu.Diagnostic.Render
  ( RenderStyle (PlainStyle)
  , interactiveRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Eval.Value (renderValue)
import Pudu.Repl.Command (Command (..), Entry (..), parseEntry)
import Pudu.Repl.Describe
  ( declarationSummary
  , describeInstances
  , describeKindLines
  , describeName
  )
import Pudu.Repl.Complete (CompletionSource (..), completionsFor, wantsFilename)
import Pudu.Repl.Session
  ( EntryKind (..)
  , EntryResult (..)
  , Session
  , contextSummary
  , emptySession
  , inspectContext
  , inspectSession
  , sessionDeclaredNames
  , sessionExports
  , submitEntry
  )
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

replProperties :: [(String, IO Property)]
replProperties =
  [ ("commands parse with unambiguous abbreviations", testCommandParsing)
  , ("submissions are classified by their leading token", testClassification)
  , ("bindings and declarations persist across entries", testPersistence)
  , ("a rejected entry leaves the session unchanged", testRejection)
  , ("diagnostics are reported against the typed line", testInteractiveLocation)
  , ("inspection reports the session context without changing it", testInspection)
  , ("describing a name reports how the session declared it", testDescribe)
  , ("kinds report declared arity", testKinds)
  , ("completion offers commands paths and session names", testCompletion)
  , ("loops and iteration evaluate in the interactive session", testIteration)
  , ("trait methods dispatch and inherit in the session", testTraits)
  , ("runtime errors surface and leave the session unchanged", testRuntimeErrors)
  , ("recursion and return interact with loops", testRecursionAndReturn)
  , ("control transfers are confined to their owning construct", testControlTransfer)
  , ("iteration edge cases are handled correctly", testIterationEdges)
  , ("operators short-circuit and index correctly", testOperators)
  , ("match expressions bind and guard correctly", testMatch)
  ]

testCommandParsing :: IO Property
testCommandParsing =
  pure $ conjoin
    [ parseEntry ":quit" === CommandEntry Quit
    , parseEntry ":q" === CommandEntry Quit
    , parseEntry ":?" === CommandEntry Help
    , parseEntry ":help" === CommandEntry Help
    , parseEntry ":load demo.pudu" === CommandEntry (Load "demo.pudu")
    , parseEntry ":l demo.pudu" === CommandEntry (Load "demo.pudu")
    , parseEntry ":t 1 + 2" === CommandEntry (ShowType "1 + 2")
    , parseEntry ":{" === CommandEntry BeginBlock
    , parseEntry ":}" === CommandEntry EndBlock
    , counterexample "a prefix resolves to the first matching command"
        (parseEntry ":r" === CommandEntry Reload)
    , counterexample "a longer prefix reaches the later command"
        (parseEntry ":res" === CommandEntry Reset)
    , counterexample "an unknown command keeps its name"
        (parseEntry ":nope" === CommandEntry (Unknown "nope"))
    , parseEntry "1 + 2" === SourceEntry "1 + 2"
    , parseEntry "   " === BlankEntry
    ]

testClassification :: IO Property
testClassification = do
  expression <- submit emptySession "1 + 2"
  binding <- submit emptySession "let value = 1"
  declaration <- submit emptySession "fn run() -> Int { 1 }"
  importEntry <- submit emptySession "import Core.Text {trim}"
  pure $ conjoin
    [ resultKind expression === ExpressionEntry
    , resultKind binding === StatementEntry
    , resultKind declaration === DeclarationEntry
    , resultKind importEntry === ImportEntry
    , counterexample "an expression reports its value" (valueOf expression === "3")
    , counterexample "a binding reports no value" (valueOf binding === "none")
    ]

testPersistence :: IO Property
testPersistence = do
  first <- submit emptySession "let base = 10"
  second <- submit (resultSession first) "fn twice(n: Int) -> Int { n * 2 }"
  third <- submit (resultSession second) "twice(base)"
  expressionForgotten <- submit (resultSession third) "base"
  pure $ conjoin
    [ counterexample "the binding is used by a later entry" (valueOf third === "20")
    , counterexample "an expression adds nothing to the context"
        (length (contextSummary (resultSession third)) === 2)
    , valueOf expressionForgotten === "10"
    ]

testRejection :: IO Property
testRejection = do
  accepted <- submit emptySession "let kept = 1"
  rejected <- submit (resultSession accepted) "let broken = missing"
  after <- submit (resultSession rejected) "kept"
  pure $ conjoin
    [ counterexample "the failed entry is not accepted" (property (not (resultAccepted rejected)))
    , codesOf rejected === ["E2010"]
    , counterexample "the session is unchanged"
        (contextSummary (resultSession rejected) === contextSummary (resultSession accepted))
    , counterexample "earlier work still evaluates" (valueOf after === "1")
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

testCompletion :: IO Property
testCompletion = do
  declared <- submit emptySession "fn measure(n: Int) -> Int { n }"
  (resolution, _) <- inspectSession (resultSession declared)
  let source = CompletionSource{sourceSessionNames = maybe [] sessionDeclaredNames resolution}
      empty = CompletionSource{sourceSessionNames = []}
  pure $ conjoin
    [ counterexample "commands complete at the start of a line"
        (completionsFor empty Text.empty ":q" === [":quit"])
    , counterexample "a colon later in the line is not a command"
        (completionsFor empty "value " ":q" === [])
    , counterexample "keywords complete"
        (completionsFor empty Text.empty "impo" === ["import"])
    , counterexample "wired-in types complete"
        (completionsFor empty Text.empty "Int1" === ["Int128", "Int16"])
    , counterexample "prelude names complete"
        (completionsFor empty Text.empty "Iterat" === ["Iterator"])
    , counterexample "session declarations complete"
        (completionsFor source Text.empty "meas" === ["measure"])
    , counterexample "an unknown prefix offers nothing"
        (completionsFor source Text.empty "zzz" === [])
    , counterexample "a filename is wanted after :load"
        (property (wantsFilename ":load "))
    , counterexample "a filename is not wanted before the space"
        (property (not (wantsFilename ":load")))
    , counterexample "a filename is not wanted for other commands"
        (property (not (wantsFilename ":type ")))
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
  indexRange <- submit emptySession "(1, 2, 3)[5]"
  undefinedName <- submit emptySession "missing + 1"
  nonExhaustive <- submit emptySession "match 5 {\n  case 0 => 0\n}"
  typeMismatch <- submit emptySession "1 + \"a\""
  after <- submit (resultSession divZeroStmt) "1 + 2"
  pure $ conjoin
    [ counterexample "division by zero is E7004" (codesOf divZero === ["E7004"])
    , counterexample "a runtime error rejects the entry" (not (resultAccepted divZeroStmt))
    , counterexample "index out of range is E7004" (codesOf indexRange === ["E7004"])
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
  breakOutsideCall <- submit (resultSession breakOutside) "bad()"
  pure $ conjoin
    [ counterexample "break exits only the inner loop" (valueOf nestedOuter === "4")
    , counterexample "the inner loop accumulates across outer iterations" (valueOf nestedInner === "4")
    , counterexample "break in for stops iteration" (valueOf breakResult === "2")
    , counterexample "continue in for skips one element" (valueOf continueResult === "4")
    , counterexample "break outside a loop is a runtime E7006" (codesOf breakOutsideCall === ["E7006"])
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
  negativeIndex <- submit emptySession "(1, 2, 3)[-1]"
  outOfRange <- submit emptySession "(1, 2)[10]"
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

{-| `:info`, `:instances`, and `:show declarations` all read the session's own
    module, so one populated session answers for all three. -}
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

{-| Arity is reported for declared types and for the types the compiler wires
    in, because a reader cannot tell the two apart from the prompt. -}
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

feed :: Session -> [Text] -> IO Session
feed session [] = pure session
feed session (entry : rest) = do
  result <- submitEntry session entry
  feed (resultSession result) rest

submit :: Session -> Text -> IO EntryResult
submit = submitEntry

valueOf :: EntryResult -> Text
valueOf result = maybe "none" renderValue (resultValue result)

codesOf :: EntryResult -> [Text]
codesOf = map codeOf . resultDiagnostics

codeOf :: Diagnostic -> Text
codeOf = diagnosticCodeText . diagnosticCode
