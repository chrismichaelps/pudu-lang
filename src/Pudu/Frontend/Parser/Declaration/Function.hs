{-| @Program.Parser.Declaration.Function — parses function signatures and bodies -}
module Pudu.Frontend.Parser.Declaration.Function
  ( parseFunction
  , parseFunctionValue
  , parseParameters
  , parseReturnType
  ) where

import Pudu.Frontend.Parser.Declaration.Block (parseBlock)
import Pudu.Frontend.Parser.Declaration.Generic (parseTypeParams, parseWhereClause)
import Pudu.Frontend.Parser.Expression (parseExpression)
import Pudu.Frontend.Parser.Name (expectValueIdentifier)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , emitParseError
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
  ( Capability (..)
  , Declaration (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , Parameter (..)
  , TypeSyntax
  , Visibility
  )
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwComptime, KwFn, KwNull, KwUnsafe)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span, mergeSpans)

{-| Parse a module-scope or impl-scope function, whose body is mandatory. -}
parseFunction :: Visibility -> Parser (Located Declaration)
parseFunction visibility = do
  value <- parseFunctionValue visibility True
  pure (Located (locatedSpan value) (FunctionDeclaration (locatedValue value)))

{-| Parse `async? fn name[params](inputs) -> type? where? body`. A trait member
    may declare a signature with no body, which is the only case where
    `bodyRequired` is `False`. -}
parseFunctionValue :: Visibility -> Bool -> Parser (Located Function)
parseFunctionValue visibility bodyRequired = do
  start <- peekToken
  comptimeKeyword <- matchKeyword KwComptime
  unsafety <- parseUnsafety
  asyncKeyword <- matchKeyword KwAsync
  _ <- expectKeyword KwFn "to start a function"
  name <- expectValueIdentifier "after fn"
  typeParams <- parseTypeParams
  _ <- expectSymbol "(" "before the parameter list"
  parameters <- parseParameters []
  _ <- expectSymbol ")" "after the parameter list"
  returnType <- parseReturnType
  constraints <- parseWhereClause
  body <- parseBody bodyRequired
  let endSpan = maybe (tokenSpan start) locatedSpan body
  pure
    ( Located (mergedOrLeft (tokenSpan start) endSpan)
        Function
          { functionVisibility = visibility
          , functionAsync = maybe False (const True) asyncKeyword
          , functionUnsafe = unsafety
          , functionComptime = maybe False (const True) comptimeKeyword
          , functionName = name
          , functionTypeParams = typeParams
          , functionParameters = parameters
          , functionReturn = returnType
          , functionConstraints = constraints
          , functionBody = body
          }
    )

{-| An `unsafe` function may name the capabilities its body needs, as in
    `unsafe(raw, foreign) fn`. Naming none grants every capability, which is the
    blanket form; naming some is the precise one, and a caller must grant at
    least what the declaration asked for. -}
parseUnsafety :: Parser (Maybe [Located Capability])
parseUnsafety = do
  keyword <- matchKeyword KwUnsafe
  case keyword of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseCapabilities

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

parseParameters :: [Located Parameter] -> Parser [Located Parameter]
parseParameters reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
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

{-| A body's opening `{` is admitted even on a new line because a signature
    alone is never a complete declaration. A latched budget stops body parsing
    without a diagnostic so one `E1099` never cascades into a missing body. -}
parseBody :: Bool -> Parser (Maybe (Located FunctionBody))
parseBody bodyRequired = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if exhausted
    then pure Nothing
    else if isSymbol "{" kind
      then do
        block <- parseBlock
        pure (Just (Located (locatedSpan block) (BlockBody block)))
      else do
        equals <- matchSymbol "="
        case equals of
          Just _ -> do
            value <- parseExpression parseBlock
            pure (Just (Located (locatedSpan value) (ExpressionBody value)))
          Nothing
            | not bodyRequired -> pure Nothing
            | otherwise -> do
                spanValue <- currentSpan
                emitParseError "E1032" spanValue "expected a function body"
                  (Just "add a block, or = followed by one expression")
                pure
                  ( Just
                      ( Located spanValue
                          (ExpressionBody (Located spanValue InvalidExpression))
                      )
                  )

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
