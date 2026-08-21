module Pudu.DiagnosticSpec (diagnosticProperties) where

import Data.Text (Text)
import Pudu.Diagnostic (DiagnosticCode (DiagnosticCode), Related (Related), Severity (Error, Note, Warning),
  diagnostic, diagnosticCode, diagnosticHelp, diagnosticMessage, diagnosticRelated, diagnosticSeverity,
  diagnosticSpan, hasErrors, sortDiagnostics, withHelp, withRelated)
import Pudu.Source (SourceName (SourceName), Span, mkSpan, newSource, sourceLength, zeroOffset)
import Test.QuickCheck (Property, conjoin, counterexample, forAll, property, shuffle, (===))

diagnosticProperties :: [(String, IO Property)]
diagnosticProperties =
  [ ("diagnostics normalize construction", testConstruction)
  , ("diagnostic decorators preserve causality", testDecorators)
  , ("diagnostic ordering is permutation-independent", testDeterministicOrder)
  , ("diagnostic error gating uses severity", testErrorGate)
  ]

testConstruction :: IO Property
testConstruction = do
  maybeSpan <- wholeSpan "construct.pudu" "value"
  pure $ case maybeSpan of
    Nothing -> counterexample "fixture span construction failed" False
    Just spanValue ->
      let value = diagnostic (DiagnosticCode "P0001") Warning spanValue ""
       in conjoin
            [ diagnosticCode value === DiagnosticCode "P0001"
            , diagnosticSeverity value === Warning
            , diagnosticSpan value === spanValue
            , diagnosticMessage value === "compiler diagnostic P0001"
            , diagnosticHelp value === Nothing
            , diagnosticRelated value === []
            ]

testDecorators :: IO Property
testDecorators = do
  primary <- wholeSpan "primary.pudu" "main"
  first <- wholeSpan "first.pudu" "one"
  second <- wholeSpan "second.pudu" "two"
  pure $ case (primary, first, second) of
    (Just primarySpan, Just firstSpan, Just secondSpan) ->
      let firstRelated = Related firstSpan "declared here"
          secondRelated = Related secondSpan "required here"
          value =
            withRelated secondRelated
              (withRelated firstRelated (withHelp "change the type" (diagnostic (DiagnosticCode "T0001") Error primarySpan "mismatch")))
       in conjoin
            [ diagnosticHelp value === Just "change the type"
            , diagnosticRelated value === [firstRelated, secondRelated]
            ]
    _ -> counterexample "fixture span construction failed" False

testDeterministicOrder :: IO Property
testDeterministicOrder = do
  first <- wholeSpan "a.pudu" "a"
  second <- wholeSpan "b.pudu" "b"
  relatedA <- wholeSpan "detail.pudu" "a"
  relatedB <- wholeSpan "detail.pudu" "b"
  pure $ case (first, second, relatedA, relatedB) of
    (Just firstSpan, Just secondSpan, Just relatedSpanA, Just relatedSpanB) ->
      let code = DiagnosticCode "T0002"
          earlier = diagnostic code Error firstSpan "alpha"
          laterMessage = diagnostic code Error firstSpan "omega"
          laterRelated = withRelated (Related relatedSpanB "z") laterMessage
          earlierRelated = withRelated (Related relatedSpanA "a") laterMessage
          otherSource = diagnostic code Note secondSpan "alpha"
          expected = [earlier, laterMessage, earlierRelated, laterRelated, otherSource]
       in forAll (shuffle (reverse expected)) $ \permutation ->
            sortDiagnostics permutation === expected
    _ -> counterexample "fixture span construction failed" False

testErrorGate :: IO Property
testErrorGate = do
  maybeSpan <- wholeSpan "gate.pudu" "x"
  pure $ case maybeSpan of
    Nothing -> counterexample "fixture span construction failed" False
    Just spanValue ->
      let errorNamedNote = diagnostic (DiagnosticCode "E9999") Note spanValue "note"
          neutralError = diagnostic (DiagnosticCode "N0001") Error spanValue "error"
       in conjoin
            [ property (not (hasErrors [errorNamedNote]))
            , property (hasErrors [errorNamedNote, neutralError])
            ]

wholeSpan :: Text -> Text -> IO (Maybe Span)
wholeSpan name contents = do
  source <- newSource (SourceName name) contents
  pure (mkSpan source zeroOffset (sourceLength source))
