{-| @Program.Parser.Capability — reads the abilities an unsafe form names

    Its own module because two forms name capabilities and neither can reach the
    other: a declaration writes them before `fn`, and a type writes them before
    the function shape it describes. One reader means one vocabulary and one
    diagnostic for a word that is not in it. -}
module Pudu.Frontend.Parser.Capability
  ( parseCapabilities
  , capabilityOf
  ) where

import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , emitParseError
  , expectSymbol
  , isSymbol
  , matchSymbol
  , peekKind
  , peekToken
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Capability (..))
import Pudu.Frontend.Token (Keyword (KwNull), Token (..), TokenKind (..))

parseCapabilities :: Parser [Located Capability]
parseCapabilities = do
  opening <- matchSymbol "("
  case opening of
    Nothing -> pure []
    Just _ -> do
      capabilities <- parseCapabilityList []
      _ <- expectSymbol ")" "to close the capability list"
      pure capabilities

parseCapabilityList :: [Located Capability] -> Parser [Located Capability]
parseCapabilityList reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      capability <- parseCapability
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (maybe reversed (: reversed) capability))
            Just _ -> parseCapabilityList (maybe reversed (: reversed) capability)

{-| The capability vocabulary is closed, so a misspelling is caught here rather
    than silently granting nothing. -}
parseCapability :: Parser (Maybe (Located Capability))
parseCapability = do
  token <- advanceToken
  case capabilityOf (tokenKind token) of
    Just capability -> pure (Just (Located (tokenSpan token) capability))
    Nothing -> do
      emitParseError "E1044" (tokenSpan token) "unknown unsafe capability"
        (Just "name one of raw, foreign, unchecked, or null")
      pure Nothing

capabilityOf :: TokenKind -> Maybe Capability
capabilityOf kind = case kind of
  Identifier "raw" -> Just RawCapability
  Identifier "foreign" -> Just ForeignCapability
  Identifier "unchecked" -> Just UncheckedCapability
  Keyword KwNull -> Just NullCapability
  _ -> Nothing
