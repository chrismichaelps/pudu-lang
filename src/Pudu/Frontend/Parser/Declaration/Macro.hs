{-| @Program.Parser.Declaration.Macro — parses typed syntax transformers -}
module Pudu.Frontend.Parser.Declaration.Macro
  ( parseMacro
  ) where

import Pudu.Frontend.Parser.Declaration.Block (parseBlock)
import Pudu.Frontend.Parser.Expression (parseExpression)
import Pudu.Frontend.Parser.Name (expectValueIdentifier)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , emitParseError
  , expectKeyword
  , expectSymbol
  , isSymbol
  , matchSymbol
  , peekKind
  , peekToken
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Expression (..)
  , Macro (..)
  , MacroKind (..)
  , MacroParam (..)
  , Visibility
  )
import Pudu.Frontend.Token (Keyword (KwMacro), Token (..), TokenKind (..))
import Pudu.Source (Span, mergeSpans)

{-| Parse `macro name(parameter: kind, ...) = body`.

    Each parameter declares the syntax it accepts, so a mismatched argument is
    reported against the call rather than against a matcher, and the expander
    knows which identifiers the body introduced. -}
parseMacro :: Visibility -> Parser (Located Declaration)
parseMacro visibility = do
  keyword <- expectKeyword KwMacro "to start a macro"
  name <- expectValueIdentifier "after macro"
  _ <- expectSymbol "(" "before the macro parameters"
  parameters <- parseParams []
  _ <- expectSymbol ")" "after the macro parameters"
  body <- parseMacroBody
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        ( MacroDeclaration
            Macro
              { macroVisibility = visibility
              , macroName = name
              , macroParameters = parameters
              , macroBody = body
              }
        )
    )

{-| A macro body is one expression. A block is an expression too, so a macro
    that expands to several statements writes them in braces. -}
parseMacroBody :: Parser (Located Expression)
parseMacroBody = do
  kind <- peekKind
  if isSymbol "{" kind
    then do
      block <- parseBlock
      pure (Located (locatedSpan block) (BlockExpression block))
    else do
      _ <- expectSymbol "=" "before the macro body"
      parseExpression parseBlock

parseParams :: [Located MacroParam] -> Parser [Located MacroParam]
parseParams reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      parameter <- parseParam
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (parameter : reversed))
            Just _ -> parseParams (parameter : reversed)

parseParam :: Parser (Located MacroParam)
parseParam = do
  name <- expectValueIdentifier "for the macro parameter"
  _ <- expectSymbol ":" "before the parameter's syntax kind"
  kind <- parseKind
  pure
    ( Located (locatedSpan name)
        MacroParam{macroParamName = name, macroParamKind = kind}
    )

{-| The kind vocabulary is closed, so a misspelling is caught at the
    declaration rather than becoming a parameter that accepts nothing. -}
parseKind :: Parser MacroKind
parseKind = do
  token <- advanceToken
  case tokenKind token of
    Identifier "expr" -> pure ExpressionKind
    Identifier "ident" -> pure IdentifierKind
    Identifier "block" -> pure BlockKind
    _ -> do
      emitParseError "E1045" (tokenSpan token) "unknown macro parameter kind"
        (Just "name one of expr, ident, or block")
      pure ExpressionKind

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
