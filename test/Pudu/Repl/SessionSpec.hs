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
import Pudu.Repl.Session
  ( EntryKind (..)
  , EntryResult (..)
  , Session
  , contextSummary
  , emptySession
  , inspectSession
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

submit :: Session -> Text -> IO EntryResult
submit = submitEntry

valueOf :: EntryResult -> Text
valueOf result = maybe "none" renderValue (resultValue result)

codesOf :: EntryResult -> [Text]
codesOf = map codeOf . resultDiagnostics

codeOf :: Diagnostic -> Text
codeOf = diagnosticCodeText . diagnosticCode
