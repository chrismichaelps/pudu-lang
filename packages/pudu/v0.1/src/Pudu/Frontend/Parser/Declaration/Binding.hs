{-| @Module.Parser.Declaration.Binding — parses scope-safe binding declarations -}
module Pudu.Frontend.Parser.Declaration.Binding
  ( parseTopConst
  , parseLocalBinding
  ) where

import Data.Text (Text)
import Pudu.Frontend.Parser.Expression (BlockParser, parseExpression)
import Pudu.Frontend.Parser.Name (expectConstantIdentifier, expectValueIdentifier)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , currentSpan
  , emitParseError
  , matchSymbol
  , peekToken
  )
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( BindingKind (..)
  , Declaration (..)
  , Expression (InvalidExpression)
  , TypeSyntax
  , Visibility (..)
  )
import Pudu.Frontend.Token
  ( Keyword (KwConst, KwLet, KwVar)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span, mergeSpans)

{-| Parse a module-scope constant. Only `const` is admitted at module scope, so
    the binding grammar cannot represent an illegal module `let` or `var`;
    visibility is owned by the orchestrator that admitted the declaration. -}
parseTopConst :: Visibility -> BlockParser -> Parser (Located Declaration)
parseTopConst visibility blockParser = do
  keyword <- peekToken
  case tokenKind keyword of
    Keyword KwConst -> do
      _ <- advanceToken
      name <- expectConstantIdentifier "after const"
      annotation <- parseOptionalType
      (value, endSpan) <- parseInitializer blockParser
      pure
        ( Located (mergedOrLeft (tokenSpan keyword) endSpan)
            (BindingDeclaration visibility CompileTime name annotation value)
        )
    _ -> unadmittedModuleBinding

{-| A module-scope binding that is not `const` is rejected once. The offending
    keyword is consumed so declaration parsing keeps making progress, and no
    name, type, or initializer diagnostics cascade behind the rejection. -}
unadmittedModuleBinding :: Parser (Located Declaration)
unadmittedModuleBinding = do
  spanValue <- currentSpan
  emitParseError "E1001" spanValue "module scope admits only const bindings"
    (Just "use const at module scope, or move let and var into a function block")
  _ <- advanceToken
  pure (Located spanValue InvalidDeclaration)

{-| Parse a block-local `let`, `var`, or `const` binding. Local bindings are
    always private syntax nodes; both the binding kind and the required name
    class are derived from the single admitted keyword. -}
parseLocalBinding :: BlockParser -> Parser (Located Declaration)
parseLocalBinding blockParser = do
  keywordToken <- peekToken
  case bindingKindOf (tokenKind keywordToken) of
    Nothing -> unadmittedBinding
    Just bindingKind -> do
      _ <- advanceToken
      name <- expectBindingName bindingKind
      annotation <- parseOptionalType
      (value, endSpan) <- parseInitializer blockParser
      pure
        ( Located (mergedOrLeft (tokenSpan keywordToken) endSpan)
            (BindingDeclaration Private bindingKind name annotation value)
        )

bindingKindOf :: TokenKind -> Maybe BindingKind
bindingKindOf kind = case kind of
  Keyword KwLet -> Just Immutable
  Keyword KwVar -> Just Mutable
  Keyword KwConst -> Just CompileTime
  _ -> Nothing

expectBindingName :: BindingKind -> Parser (Located Text)
expectBindingName bindingKind = case bindingKind of
  Immutable -> expectValueIdentifier "after let"
  Mutable -> expectValueIdentifier "after var"
  CompileTime -> expectConstantIdentifier "after const"

{-| Defensive path for a caller that dispatched here without a binding keyword.
    One token is consumed so block parsing keeps making progress, and no
    fabricated name or initializer diagnostics are emitted after it. -}
unadmittedBinding :: Parser (Located Declaration)
unadmittedBinding = do
  spanValue <- currentSpan
  emitParseError "E1001" spanValue "expected let, var, or const"
    (Just "start a local binding with let, var, or const")
  _ <- advanceToken
  pure (Located spanValue InvalidDeclaration)

parseOptionalType :: Parser (Maybe (Located TypeSyntax))
parseOptionalType = do
  colon <- matchSymbol ":"
  case colon of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseTypeSyntax

{-| Require `=` then delegate the initializer to expression parsing through the
    injected block capability. A missing `=` diagnoses without consuming the
    following expression; a missing initializer keeps the expression parser's
    own `E1040` recovery node, and an exhausted expression budget reports only
    the owning `E1099`. -}
parseInitializer :: BlockParser -> Parser (Located Expression, Span)
parseInitializer blockParser = do
  equals <- matchSymbol "="
  case equals of
    Just _ -> do
      value <- parseExpression blockParser
      pure (value, locatedSpan value)
    Nothing -> do
      spanValue <- currentSpan
      emitParseError "E1001" spanValue "expected = before the binding value"
        (Just "add = followed by the binding value")
      pure (Located spanValue InvalidExpression, spanValue)

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
