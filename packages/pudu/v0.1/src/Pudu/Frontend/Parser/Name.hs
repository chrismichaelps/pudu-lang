{-| @Module.Parser.Name — parses segmented source paths -}
module Pudu.Frontend.Parser.Name
  ( expectConstantIdentifier
  , expectUpperIdentifier
  , expectValueIdentifier
  , parseModuleName
  , parseNamePath
  ) where

import Data.Char (isDigit, isUpper)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Parser.State
  ( Parser
  , emitParseError
  , expectIdentifier
  , matchSymbol
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (ModuleName))
import Pudu.Source (Span, mergeSpans)

parseModuleName :: Parser (Located ModuleName)
parseModuleName = do
  segments@(first :| rest) <- parseSegments
  mapM_ validateUpper (first : rest)
  pure (Located (segmentsSpan segments) (ModuleName (fmap locatedValue segments)))

parseNamePath :: Parser (Located (NonEmpty Text))
parseNamePath = do
  segments <- parseSegments
  pure (Located (segmentsSpan segments) (fmap locatedValue segments))

expectUpperIdentifier :: Text -> Parser (Located Text)
expectUpperIdentifier context = do
  identifier <- expectIdentifier context
  if Text.null (locatedValue identifier)
    then pure ()
    else validateUpper identifier
  pure identifier

expectValueIdentifier :: Text -> Parser (Located Text)
expectValueIdentifier context = do
  identifier <- expectIdentifier context
  if Text.null (locatedValue identifier)
    then pure ()
    else validateValue identifier
  pure identifier

expectConstantIdentifier :: Text -> Parser (Located Text)
expectConstantIdentifier context = do
  identifier <- expectIdentifier context
  if Text.null (locatedValue identifier)
    then pure ()
    else validateConstant identifier
  pure identifier

parseSegments :: Parser (NonEmpty (Located Text))
parseSegments = do
  first <- expectIdentifier "for this name"
  rest <- parseRemaining
  pure (first :| rest)
 where
  parseRemaining = do
    dot <- matchSymbol "."
    case dot of
      Nothing -> pure []
      Just _ -> do
        bounded <- withRecursionBudget $ do
          segment <- expectIdentifier "after ."
          if Text.null (locatedValue segment)
            then pure []
            else (segment :) <$> parseRemaining
        pure (maybe [] id bounded)

validateUpper :: Located Text -> Parser ()
validateUpper Located{locatedSpan, locatedValue} =
  case fmap fst (Text.uncons locatedValue) of
    Just first | isUpper first -> pure ()
    _ ->
      emitParseError "E1011" locatedSpan "module path segment must start uppercase"
        (Just "start module and type path segments with an uppercase letter")

validateValue :: Located Text -> Parser ()
validateValue Located{locatedSpan, locatedValue} =
  case fmap fst (Text.uncons locatedValue) of
    Just first
      | first == '_' && Text.length locatedValue == 1 ->
          emitParseError "E1012" locatedSpan "single _ is reserved for discard patterns"
            (Just "use a descriptive name that starts with _ or a lowercase letter")
      | first /= '_' && isUpper first ->
          emitParseError "E1012" locatedSpan "value name must start lowercase or _"
            (Just "use snake_case or camelCase for value names")
      | otherwise -> pure ()
    _ -> pure ()

validateConstant :: Located Text -> Parser ()
validateConstant Located{locatedSpan, locatedValue} =
  case Text.uncons locatedValue of
    Just (first, _)
      | validConstantStart first
      , Text.all validConstantChar locatedValue
      , Text.any isUpper locatedValue
        -> pure ()
      | otherwise ->
          emitParseError "E1013" locatedSpan "constant name must use UPPER_SNAKE_CASE"
            (Just "use only uppercase letters, digits, and underscores; at least one uppercase letter is required")
    Nothing -> pure ()
 where
  validConstantStart c = c == '_' || isUpper c
  validConstantChar c = c == '_' || isUpper c || isDigit c

segmentsSpan :: NonEmpty (Located Text) -> Span
segmentsSpan (first :| rest) =
  case reverse rest of
    final : _ -> mergedOrLeft (locatedSpan first) (locatedSpan final)
    [] -> locatedSpan first

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
