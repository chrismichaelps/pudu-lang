module Pudu.DiagnosticSpec (diagnosticProperties) where

import Data.Text (Text)
import Pudu.Diagnostic (Diagnostic, Related (Related), Severity (Error, Note, Warning),
  diagnostic, diagnosticCode, diagnosticCodeText, diagnosticHelp, diagnosticMessage, diagnosticRelated,
  diagnosticSeverity, diagnosticSpan, hasErrors, mkDiagnosticCode, sortDiagnostics, withHelp, withRelated)
import Pudu.Source (Offset, Source, SourceName (SourceName), Span, mkSpan, newSource, offsetFromInt,
  sourceLength, spanEnd, spanSource, spanStart, zeroOffset)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

diagnosticProperties :: [(String, IO Property)]
diagnosticProperties =
  [ ("diagnostic codes validate groups", testCodeValidation)
  , ("diagnostics normalize construction", testConstruction)
  , ("diagnostic decorators preserve causality", testDecorators)
  , ("diagnostic ordering covers every render key", testOrderingKey)
  , ("snapshot-distinct diagnostics render equivalently", testSnapshotEquivalence)
  , ("diagnostic error gating uses severity", testErrorGate)
  ]

testCodeValidation :: IO Property
testCodeValidation =
  pure
    ( conjoin
        [ property (mkDiagnosticCode "E0001" /= Nothing)
        , property (mkDiagnosticCode "W7999" /= Nothing)
        , mkDiagnosticCode "" === Nothing
        , mkDiagnosticCode "N0001" === Nothing
        , mkDiagnosticCode "E8001" === Nothing
        , mkDiagnosticCode "E00²1" === Nothing
        , mkDiagnosticCode "E00001" === Nothing
        ]
    )

testConstruction :: IO Property
testConstruction = do
  maybeSpan <- wholeSpan "construct.pudu" "value"
  pure $ case (maybeSpan, mkDiagnosticCode "W0001") of
    (Just spanValue, Just code) ->
      case diagnostic code Warning spanValue "" of
        Nothing -> counterexample "valid diagnostic construction failed" False
        Just value ->
          conjoin
            [ diagnosticCodeText (diagnosticCode value) === "W0001"
            , diagnosticSeverity value === Warning
            , diagnosticSpan value === spanValue
            , diagnosticMessage value === "compiler diagnostic W0001"
            , diagnosticHelp value === Nothing
            , diagnosticRelated value === []
            , property (diagnostic code Note spanValue "note" /= Nothing)
            , diagnostic code Error spanValue "wrong family" === Nothing
            ]
    _ -> counterexample "fixture construction failed" False

testDecorators :: IO Property
testDecorators = do
  primary <- wholeSpan "primary.pudu" "main"
  first <- wholeSpan "first.pudu" "one"
  second <- wholeSpan "second.pudu" "two"
  pure $ case (primary, first, second, mkDiagnosticCode "E3001") of
    (Just primarySpan, Just firstSpan, Just secondSpan, Just code) ->
      case diagnostic code Error primarySpan "mismatch" of
        Nothing -> counterexample "valid diagnostic construction failed" False
        Just base ->
          let firstRelated = Related firstSpan "declared here"
              secondRelated = Related secondSpan "required here"
              value = withRelated secondRelated (withRelated firstRelated (withHelp "change the type" base))
           in conjoin
                [ diagnosticCode value === code
                , diagnosticSeverity value === Error
                , diagnosticSpan value === primarySpan
                , diagnosticMessage value === "mismatch"
                , diagnosticHelp value === Just "change the type"
                , diagnosticRelated value === [firstRelated, secondRelated]
                ]
    _ -> counterexample "fixture construction failed" False

testOrderingKey :: IO Property
testOrderingKey = do
  sourceA <- newSource (SourceName "a.pudu") "abc"
  sourceB <- newSource (SourceName "b.pudu") "abc"
  let spans = (spanAt sourceA 0 1, spanAt sourceA 0 2, spanAt sourceA 1 2, spanAt sourceB 0 1)
  pure $ case (spans, mkDiagnosticCode "E0001", mkDiagnosticCode "E0002") of
    ((Just short, Just long, Just later, Just other), Just firstCode, Just secondCode) ->
      case
          ( diagnostic firstCode Error short "alpha"
          , diagnostic secondCode Error short "alpha"
          , diagnostic firstCode Note short "alpha"
          , diagnostic firstCode Error other "alpha"
          , diagnostic firstCode Error later "alpha"
          , diagnostic firstCode Error long "alpha"
          , diagnostic firstCode Error short "omega"
          ) of
        (Just base, Just laterCode, Just laterSeverity, Just otherSource, Just laterStart, Just laterEnd, Just laterMessage) ->
          let
              laterHelp = withHelp "help" base
              relatedShort = withRelated (Related short "a") base
              relatedLong = withRelated (Related long "a") base
              relatedLater = withRelated (Related later "a") base
              relatedOther = withRelated (Related other "a") base
              relatedMessage = withRelated (Related short "z") base
              relatedTwice = withRelated (Related short "z") relatedShort
              relatedOrderEarlier = withRelated (Related long "b") relatedShort
              relatedOrderLater = withRelated (Related short "a") relatedLong
              pairs =
                [ (base, otherSource)
                , (base, laterStart)
                , (base, laterEnd)
                , (base, laterSeverity)
                , (base, laterCode)
                , (base, laterMessage)
                , (base, laterHelp)
                , (relatedShort, relatedLong)
                , (relatedShort, relatedLater)
                , (relatedShort, relatedOther)
                , (relatedShort, relatedMessage)
                , (relatedShort, relatedTwice)
                , (relatedOrderEarlier, relatedOrderLater)
                ]
           in conjoin (map (uncurry orderedPair) pairs)
        _ -> counterexample "valid diagnostic construction failed" False
    _ -> counterexample "fixture construction failed" False

testSnapshotEquivalence :: IO Property
testSnapshotEquivalence = do
  first <- wholeSpan "same.pudu" "x"
  second <- wholeSpan "same.pudu" "x"
  pure $ case (first, second, mkDiagnosticCode "E0001") of
    (Just firstSpan, Just secondSpan, Just code) ->
      case (diagnostic code Error firstSpan "same", diagnostic code Error secondSpan "same") of
        (Just left, Just right) ->
          conjoin
            [ property (left /= right)
            , map visibleKey (sortDiagnostics [left, right]) === map visibleKey (sortDiagnostics [right, left])
            ]
        _ -> counterexample "valid diagnostic construction failed" False
    _ -> counterexample "fixture construction failed" False

testErrorGate :: IO Property
testErrorGate = do
  maybeSpan <- wholeSpan "gate.pudu" "x"
  pure $ case (maybeSpan, mkDiagnosticCode "E7001") of
    (Just spanValue, Just code) ->
      case (diagnostic code Note spanValue "note", diagnostic code Error spanValue "error") of
        (Just noteValue, Just errorValue) ->
          conjoin
            [ property (not (hasErrors [noteValue]))
            , property (hasErrors [noteValue, errorValue])
            , diagnostic code Warning spanValue "wrong family" === Nothing
            ]
        _ -> counterexample "valid diagnostic construction failed" False
    _ -> counterexample "fixture construction failed" False

orderedPair :: Diagnostic -> Diagnostic -> Property
orderedPair earlier later =
  conjoin
    [ sortDiagnostics [earlier, later] === [earlier, later]
    , sortDiagnostics [later, earlier] === [earlier, later]
    ]

visibleKey :: Diagnostic -> (SourceName, Offset, Offset, Severity, Text, Text, Maybe Text, [(SourceName, Offset, Offset, Text)])
visibleKey value =
  ( spanSource spanValue
  , spanStart spanValue
  , spanEnd spanValue
  , diagnosticSeverity value
  , diagnosticCodeText (diagnosticCode value)
  , diagnosticMessage value
  , diagnosticHelp value
  , map relatedKey (diagnosticRelated value)
  )
 where
  spanValue = diagnosticSpan value

relatedKey :: Related -> (SourceName, Offset, Offset, Text)
relatedKey (Related spanValue message) =
  (spanSource spanValue, spanStart spanValue, spanEnd spanValue, message)

wholeSpan :: Text -> Text -> IO (Maybe Span)
wholeSpan name contents = do
  source <- newSource (SourceName name) contents
  pure (mkSpan source zeroOffset (sourceLength source))

spanAt :: Source -> Int -> Int -> Maybe Span
spanAt source start end = do
  startOffset <- offsetFromInt start
  endOffset <- offsetFromInt end
  mkSpan source startOffset endOffset
