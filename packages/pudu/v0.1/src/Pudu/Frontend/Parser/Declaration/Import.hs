{-| @Module.Parser.Declaration.Import — parses bounded import declarations -}
module Pudu.Frontend.Parser.Declaration.Import
  ( parseImport
  , parseImports
  ) where

import Data.Text (Text)
import Pudu.Frontend.Parser.Name (expectUpperIdentifier, parseModuleName)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , emitParseError
  , expectIdentifier
  , expectKeyword
  , expectSymbol
  , isSymbol
  , matchKeyword
  , matchSymbol
  , peekKind
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Import (..))
import Pudu.Frontend.Token (Keyword (KwAs, KwImport), Token (..), TokenKind (..))
import Pudu.Source (Span, mergeSpans)

parseImports :: Parser [Located Import]
parseImports = do
  kind <- peekKind
  case kind of
    Keyword KwImport -> do
      bounded <- withRecursionBudget $ do
        current <- parseImport
        remaining <- parseImports
        pure (current : remaining)
      pure (maybe [] id bounded)
    _ -> pure []

parseImport :: Parser (Located Import)
parseImport = do
  opening <- expectKeyword KwImport "to start an import"
  importedModule <- parseModuleName
  aliasMarker <- matchKeyword KwAs
  alias <- traverse (const (expectUpperIdentifier "after as")) aliasMarker
  selectionMarker <- matchSymbol "{"
  case (alias, selectionMarker) of
    (Just _, Just marker) ->
      emitParseError
        "E1031"
        (tokenSpan marker)
        "import cannot combine an alias with an item selection"
        (Just "use either as Alias or {Item}, but not both")
    _ -> pure ()
  (items, selectionEnd) <- case selectionMarker of
    Nothing -> pure ([], Nothing)
    Just marker -> parseSelection marker
  let endSpan = importEndSpan importedModule alias selectionMarker items selectionEnd
      declarationSpan = mergedOrLeft (tokenSpan opening) endSpan
  pure
    (Located declarationSpan Import
      { importModule = importedModule
      , importAlias = alias
      , importItems = items
      })

parseSelection :: Token -> Parser ([Located Text], Maybe Token)
parseSelection _opening = do
  kind <- peekKind
  if isSymbol "}" kind
    then do
      closing <- advanceToken
      emitParseError
        "E1030"
        (tokenSpan closing)
        "import selection must contain at least one item"
        (Just "remove the empty selection or name at least one imported item")
      pure ([], Just closing)
    else do
      before <- peekToken
      first <- expectIdentifier "after { in an import selection"
      after <- peekToken
      if tokenSpan before == tokenSpan after
        then pure ([], Nothing)
        else do
          (remaining, closing) <- parseSelectionTail
          pure (first : remaining, closing)
 where
  parseSelectionTail = do
    comma <- matchSymbol ","
    case comma of
      Nothing -> do
        closing <- expectSymbol "}" "to close the import selection"
        pure ([], Just closing)
      Just _ -> do
        kind <- peekKind
        if isSymbol "}" kind
          then do
            closing <- advanceToken
            pure ([], Just closing)
          else do
            bounded <- withRecursionBudget $ do
              before <- peekToken
              item <- expectIdentifier "after , in an import selection"
              after <- peekToken
              if tokenSpan before == tokenSpan after
                then pure ([], Nothing)
                else do
                  (remaining, closing) <- parseSelectionTail
                  pure (item : remaining, closing)
            pure (maybe ([], Nothing) id bounded)

importEndSpan
  :: Located imported
  -> Maybe (Located Text)
  -> Maybe Token
  -> [Located Text]
  -> Maybe Token
  -> Span
importEndSpan importedModule alias selectionMarker items selectionEnd =
  case selectionEnd of
    Just closing -> tokenSpan closing
    Nothing -> case reverse items of
      item : _ -> locatedSpan item
      [] -> case selectionMarker of
        Just marker -> tokenSpan marker
        Nothing -> maybe (locatedSpan importedModule) locatedSpan alias

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
