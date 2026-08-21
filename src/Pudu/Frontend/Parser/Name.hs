{-| @Module.Parser.Name — parses segmented source paths -}
module Pudu.Frontend.Parser.Name
  ( expectUpperIdentifier
  , parseModuleName
  , parseNamePath
  ) where

import Data.Char (isUpper)
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

segmentsSpan :: NonEmpty (Located Text) -> Span
segmentsSpan (first :| rest) =
  case reverse rest of
    final : _ -> mergedOrLeft (locatedSpan first) (locatedSpan final)
    [] -> locatedSpan first

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
