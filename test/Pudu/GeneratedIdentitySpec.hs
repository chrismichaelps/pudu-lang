module Pudu.GeneratedIdentitySpec (generatedIdentityProperties) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Cache.Persist (decodeWith, encodeFor)
import Pudu.Diagnostic
  ( Related (..), Severity (Error), diagnostic, diagnosticRelated, mkDiagnosticCode )
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..), Function (..), FunctionBody (..), Module (..) )
import Pudu.Source
  ( SourceName (SourceName), Span, emptySpan, generatedSpan, mergeSpans, newSource
  , sameSpanSource, spanEnd, spanOrigin, spanStart, unOffset )
import Pudu.Type (TypeInfo, checkTypes, typeAt, typeAtOffsets)
import Pudu.Type.Env
  ( CheckerProducts (..), admitLentArgument, evalChecker, isLentArgument
  , isWritableName, recordExpression, reportedAt, runChecker, setWritableNames )
import Pudu.Type.Value (boolType, integerType)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

generatedIdentityProperties :: [(String, IO Property)]
generatedIdentityProperties =
  [ ("generated identity preserves authored bounds and compact origins", testSpans)
  , ("generated identity isolates checker facts and place permissions", testChecker)
  , ("generated identity survives type publication and editor projection", testTypes)
  , ("generated identity retains diagnostic notes and refuses lossy persistence", testProducts)
  ]

testSpans :: IO Property
testSpans = do
  definition <- emptySpan <$> newSource (SourceName "Derive.pudu") "body"
  request <- emptySpan <$> newSource (SourceName "Request.pudu") "type"
  other <- emptySpan <$> newSource (SourceName "Request.pudu") "type"
  let first = generatedSpan 0 definition request
      next = generatedSpan 1 definition request
      elsewhere = generatedSpan 0 definition other
      regenerated = generatedSpan 2 first elsewhere
  pure $ conjoin
    [ spanStart first === spanStart definition
    , spanEnd first === spanEnd definition
    , spanOrigin first === Just (definition, request, 0)
    , property (Set.size (Set.fromList [definition, first, next, elsewhere]) == 4)
    , property (sameSpanSource first definition)
    , property (not (sameSpanSource request other))
    , mergeSpans first first === Just first
    , mergeSpans first next === Just definition
    , mergeSpans first request === Nothing
    , spanOrigin regenerated === Just (definition, definition, 2)
    ]

testChecker :: IO Property
testChecker = do
  definition <- emptySpan <$> newSource (SourceName "Derive.pudu") "body"
  request <- emptySpan <$> newSource (SourceName "Request.pudu") "type"
  let first = generatedSpan 0 definition request
      second = generatedSpan 1 definition request
      products = runChecker $ do
        recordExpression first (integerType)
        recordExpression second (boolType)
      permissions = evalChecker $ do
        setWritableNames (Set.singleton first)
        admitLentArgument first
        (,,,) <$> isWritableName first <*> isWritableName second
          <*> isLentArgument first <*> isLentArgument second
      suppression = evalChecker $ do
        a <- reportedAt first "E3001"
        b <- reportedAt second "E3001"
        c <- reportedAt first "E3001"
        d <- reportedAt first "E3002"
        pure (a, b, c, d)
  pure $ conjoin
    [ Map.fromList (producedTypes products) === Map.fromList
        [(first, integerType), (second, boolType)]
    , permissions === (True, False, True, False)
    , suppression === (False, False, True, False)
    ]

testTypes :: IO Property
testTypes = do
  source <- newSource (SourceName "Probe.pudu")
    "module Probe\nfn first() -> Int8 = 1\nfn second() -> Int16 = 1\n"
  let LexResult tokens lexErrors = lexSource source
      ParseResult parsed parseErrors = parseModule source tokens
  pure $ case parsed of
    Just unit -> case moduleDeclarations unit of
      [ Located atFirst (FunctionDeclaration first)
        , Located atSecond (FunctionDeclaration second) ] ->
        case (functionBody first, functionBody second) of
          (Just (Located bodyAt (ExpressionBody (Located literalAt literal))), Just (Located secondAt (ExpressionBody _))) ->
            let a = generatedSpan 0 literalAt atFirst
                b = generatedSpan 0 literalAt atSecond
                generated = unit{moduleDeclarations =
                  [ Located atFirst (FunctionDeclaration first{functionBody = Just (Located bodyAt (ExpressionBody (Located a literal)))})
                  , Located atSecond (FunctionDeclaration second{functionBody = Just (Located secondAt (ExpressionBody (Located b literal)))})
                  ]}
                (facts, errors) = checkTypes generated
                (original, originalErrors) = checkTypes unit
             in conjoin
                [ lexErrors <> parseErrors <> errors <> originalErrors === []
                , property (typeAt facts a /= typeAt facts b)
                , property (typeAt facts a /= Nothing && typeAt facts b /= Nothing)
                , typeAt facts literalAt === Nothing
                , property (typeAt original literalAt /= Nothing)
                , noOffsetFact facts literalAt
                ]
          _ -> counterexample "expression body fixture changed" False
      _ -> counterexample "function fixture changed" False
    _ -> counterexample "fixture did not parse" False
 where
  noOffsetFact :: TypeInfo -> Span -> Property
  noOffsetFact facts location =
    typeAtOffsets (unOffset (spanStart location)) (unOffset (spanEnd location)) facts === Nothing

testProducts :: IO Property
testProducts = do
  source <- newSource (SourceName "Same.pudu") "body"
  another <- newSource (SourceName "Same.pudu") "body"
  request <- emptySpan <$> newSource (SourceName "Request.pudu") "type"
  let authored = emptySpan source
      generated = generatedSpan 0 authored request
      ordinary = decodeWith another (encodeFor source authored) :: Maybe Span
      lostOrigin = decodeWith source (encodeFor source generated) :: Maybe Span
      wrongSnapshot = decodeWith source (encodeFor source (emptySpan another)) :: Maybe Span
      notes = do
        code <- mkDiagnosticCode "E3001"
        diagnostic code Error generated "mismatch"
  pure $ conjoin
    [ ordinary === Just (emptySpan another)
    , lostOrigin === Nothing
    , wrongSnapshot === Nothing
    , fmap diagnosticRelated notes === Just
        [Related authored "derive definition", Related request "derive requested here"]
    ]
