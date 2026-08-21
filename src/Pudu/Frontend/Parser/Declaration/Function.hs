{-| @Program.Parser.Declaration.Function — parses function signatures and bodies -}
module Pudu.Frontend.Parser.Declaration.Function
  ( parseFunction
  ) where

import Pudu.Frontend.Parser.Declaration.Block (parseBlock)
import Pudu.Frontend.Parser.Expression (parseExpression)
import Pudu.Frontend.Parser.Name (expectValueIdentifier)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , currentSpan
  , emitParseError
  , expectKeyword
  , expectSymbol
  , isSymbol
  , matchKeyword
  , matchSymbol
  , peekKind
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Expression (..)
  , FunctionBody (..)
  , Parameter (..)
  , TypeSyntax
  , Visibility
  )
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwFn, KwWhere)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span, mergeSpans)

{-| Parse `async? fn name(params) -> type? body`. Visibility is resolved by the
    orchestrator that consumed `export`, so this module never invents public
    API. -}
parseFunction :: Visibility -> Parser (Located Declaration)
parseFunction visibility = do
  start <- peekToken
  asyncKeyword <- matchKeyword KwAsync
  _ <- expectKeyword KwFn "to start a function"
  name <- expectValueIdentifier "after fn"
  skipReservedGenerics
  _ <- expectSymbol "(" "before the parameter list"
  parameters <- parseParameters []
  _ <- expectSymbol ")" "after the parameter list"
  returnType <- parseReturnType
  skipReservedWhere
  body <- parseBody
  pure
    ( Located (mergedOrLeft (tokenSpan start) (locatedSpan body))
        (FunctionDeclaration visibility (isAsync asyncKeyword) name parameters returnType body)
    )
 where
  isAsync = maybe False (const True)

{-| Generic parameters are grammatical but have no syntax-tree representation in
    this slice. Diagnose once and skip the balanced bracket region so the rest
    of the signature still parses. -}
skipReservedGenerics :: Parser ()
skipReservedGenerics = do
  opening <- matchSymbol "["
  case opening of
    Nothing -> pure ()
    Just token -> do
      emitParseError "E1033" (tokenSpan token) "generic parameters are reserved"
        (Just "type parameters and where clauses enter in a later semantic slice")
      skipBracketed 1

skipBracketed :: Int -> Parser ()
skipBracketed depth
  | depth <= 0 = pure ()
  | otherwise = do
      kind <- peekKind
      case kind of
        EndOfFile -> pure ()
        _ | isSymbol "[" kind -> advanceToken >> skipBracketed (depth + 1)
          | isSymbol "]" kind -> advanceToken >> skipBracketed (depth - 1)
          | otherwise -> advanceToken >> skipBracketed depth

{-| A `where` clause is bounded by the body it precedes, so recovery stops at
    the first `{` or `=` rather than guessing constraint structure. -}
skipReservedWhere :: Parser ()
skipReservedWhere = do
  clause <- matchKeyword KwWhere
  case clause of
    Nothing -> pure ()
    Just token -> do
      emitParseError "E1033" (tokenSpan token) "where clauses are reserved"
        (Just "type parameters and where clauses enter in a later semantic slice")
      skipToBody

skipToBody :: Parser ()
skipToBody = do
  kind <- peekKind
  case kind of
    EndOfFile -> pure ()
    _ | isSymbol "{" kind || isSymbol "=" kind -> pure ()
      | otherwise -> advanceToken >> skipToBody

parseParameters :: [Located Parameter] -> Parser [Located Parameter]
parseParameters reversed = do
  kind <- peekKind
  if isSymbol ")" kind || kind == EndOfFile
    then pure (reverse reversed)
    else do
      bounded <- withRecursionBudget $ do
        before <- peekToken
        parameter <- parseParameter
        after <- peekToken
        if before == after then pure Nothing else pure (Just (parameter : reversed))
      case bounded of
        Nothing -> pure (reverse reversed)
        Just Nothing -> pure (reverse reversed)
        Just (Just extended) -> do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse extended)
            Just _ -> parseParameters extended

parseParameter :: Parser (Located Parameter)
parseParameter = do
  name <- expectValueIdentifier "for the parameter"
  annotation <- parseOptionalType
  defaultValue <- parseOptionalDefault
  let annotationSpan = maybe (locatedSpan name) locatedSpan annotation
      endSpan = maybe annotationSpan locatedSpan defaultValue
  pure
    ( Located (mergedOrLeft (locatedSpan name) endSpan)
        Parameter
          { parameterName = name
          , parameterType = annotation
          , parameterDefault = defaultValue
          }
    )

parseOptionalType :: Parser (Maybe (Located TypeSyntax))
parseOptionalType = do
  colon <- matchSymbol ":"
  case colon of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseTypeSyntax

{-| Default admissibility is a semantic rule; parsing preserves the expression
    and checks nothing about what it may reference. -}
parseOptionalDefault :: Parser (Maybe (Located Expression))
parseOptionalDefault = do
  equals <- matchSymbol "="
  case equals of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseExpression parseBlock

parseReturnType :: Parser (Maybe (Located TypeSyntax))
parseReturnType = do
  arrow <- matchSymbol "->"
  case arrow of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseTypeSyntax

{-| A body is mandatory. Its opening `{` is admitted even on a new line because
    a signature alone is never a complete declaration. A latched budget stops
    body parsing without a diagnostic so one `E1099` never cascades into a
    missing-body report. -}
parseBody :: Parser (Located FunctionBody)
parseBody = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if exhausted
    then do
      spanValue <- currentSpan
      pure (Located spanValue (ExpressionBody (Located spanValue InvalidExpression)))
    else if isSymbol "{" kind
    then do
      block <- parseBlock
      pure (Located (locatedSpan block) (BlockBody block))
    else do
      equals <- matchSymbol "="
      case equals of
        Just _ -> do
          value <- parseExpression parseBlock
          pure (Located (locatedSpan value) (ExpressionBody value))
        Nothing -> do
          spanValue <- currentSpan
          emitParseError "E1032" spanValue "expected a function body"
            (Just "add a block, or = followed by one expression")
          pure (Located spanValue (ExpressionBody (Located spanValue InvalidExpression)))

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
