{-| @Program.Parser.Declaration.Block — resolves newline-delimited statements -}
module Pudu.Frontend.Parser.Declaration.Block
  ( parseBlock
  ) where

import Pudu.Frontend.Parser.Declaration.Binding (parseLocalBinding)
import Pudu.Frontend.Parser.Expression (parseExpression)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , expectSymbol
  , isSymbol
  , peekKind
  , peekStartsLine
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Block (..), Statement (..))
import Pudu.Frontend.Token (Keyword (KwConst, KwLet, KwReturn, KwVar), Token (..), TokenKind (..))
import Pudu.Source (Span, mergeSpans)

{-| Parse `{ statement* }`. This module is the fixed point of the
    declaration/statement/expression recursion: it hands itself to expression
    and binding parsing as their block capability, so neither of them needs a
    cyclic import. -}
parseBlock :: Parser (Located Block)
parseBlock = do
  opening <- expectSymbol "{" "to start the block"
  statements <- parseStatements []
  exhausted <- budgetExhausted
  if exhausted
    then pure (Located (tokenSpan opening) (toBlock statements))
    else do
      closing <- expectSymbol "}" "to close the block"
      let spanValue = mergedOrLeft (tokenSpan opening) (tokenSpan closing)
      pure (Located spanValue (toBlock statements))

{-| Statements are separated by line breaks alone; the loop stops at `}`, EOF,
    or an exhausted nesting budget. Iteration itself costs no depth — a long
    statement list is ordinary input — but each statement must consume a token,
    so an unrecognized statement start can never loop. -}
parseStatements :: [Located Statement] -> Parser [Located Statement]
parseStatements reversed = do
  kind <- peekKind
  if isSymbol "}" kind || kind == EndOfFile
    then pure (reverse reversed)
    else do
      bounded <- withRecursionBudget $ do
        before <- peekToken
        statement <- parseStatement
        after <- peekToken
        if before == after
          then advanceToken >> pure (Located (locatedSpan statement) InvalidStatement : reversed)
          else pure (statement : reversed)
      case bounded of
        Nothing -> pure (reverse reversed)
        Just extended -> do
          exhausted <- budgetExhausted
          if exhausted then pure (reverse extended) else parseStatements extended

parseStatement :: Parser (Located Statement)
parseStatement = do
  kind <- peekKind
  case kind of
    Keyword KwLet -> declarationStatement
    Keyword KwVar -> declarationStatement
    Keyword KwConst -> declarationStatement
    Keyword KwReturn -> parseReturn
    _ -> do
      expression <- parseExpression parseBlock
      pure (Located (locatedSpan expression) (ExpressionStatement expression))

declarationStatement :: Parser (Located Statement)
declarationStatement = do
  declaration <- parseLocalBinding parseBlock
  pure (Located (locatedSpan declaration) (DeclarationStatement declaration))

{-| `return` carries a value only when one follows on the same line and before
    the closing brace; parsing never inspects control-flow validity. -}
parseReturn :: Parser (Located Statement)
parseReturn = do
  keyword <- advanceToken
  kind <- peekKind
  newLine <- peekStartsLine
  if isSymbol "}" kind || kind == EndOfFile || newLine
    then pure (Located (tokenSpan keyword) (ReturnStatement Nothing))
    else do
      value <- parseExpression parseBlock
      pure
        ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan value))
            (ReturnStatement (Just value))
        )

{-| A trailing expression statement is the block result, matching "a block
    yields its final unterminated expression"; every other final entry leaves
    the result empty. -}
toBlock :: [Located Statement] -> Block
toBlock statements = case unsnoc statements of
  Just (leading, Located _ (ExpressionStatement expression)) ->
    Block{blockStatements = leading, blockResult = Just expression}
  _ -> Block{blockStatements = statements, blockResult = Nothing}

unsnoc :: [a] -> Maybe ([a], a)
unsnoc values = case reverse values of
  [] -> Nothing
  final : leading -> Just (reverse leading, final)

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
