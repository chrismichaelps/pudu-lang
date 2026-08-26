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
  , emitParseError
  , diagnosticCount
  , expectIdentifier
  , expectSymbol
  , isSymbol
  , peekKind
  , peekStartsLine
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Block (..), Expression, Statement (..))
import Pudu.Frontend.Token
  ( Keyword (KwBreak, KwConst, KwContinue, KwLet, KwReturn, KwVar)
  , SymbolKind (SymAt)
  , Token (..)
  , TokenKind (..)
  )
import Data.Text (Text)
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
parseStatements = parseStatementsFrom False

{-| `reported` carries whether this block has already named a missing line
    break, and a missing one is only worth naming when the statement before it
    parsed cleanly. One block reports one, and a statement whose own parse
    already failed reports none: a hostile `{{{{...` opens a fresh block per
    brace, and without both rules it would emit a diagnostic for every one. -}
parseStatementsFrom :: Bool -> [Located Statement] -> Parser [Located Statement]
parseStatementsFrom reported reversed = do
  kind <- peekKind
  if isSymbol "}" kind || kind == EndOfFile
    then pure (reverse reversed)
    else do
      beforeCount <- diagnosticCount
      bounded <- withRecursionBudget $ do
        before <- peekToken
        statement <- parseStatement
        after <- peekToken
        if before == after
          then do
            _ <- advanceToken
            pure (reported, Located (locatedSpan statement) InvalidStatement : reversed)
          else do
            after' <- diagnosticCount
            nowReported <- reportAdjacent (reported || after' > beforeCount) 
            pure (nowReported, statement : reversed)
      case bounded of
        Nothing -> pure (reverse reversed)
        Just (nowReported, extended) -> do
          exhausted <- budgetExhausted
          if exhausted
            then pure (reverse extended)
            else parseStatementsFrom nowReported extended

parseStatement :: Parser (Located Statement)
parseStatement = do
  kind <- peekKind
  case kind of
    Keyword KwLet -> declarationStatement
    Keyword KwVar -> declarationStatement
    Keyword KwConst -> declarationStatement
    Keyword KwReturn -> parseReturn
    Keyword KwBreak -> parseBreak
    Keyword KwContinue -> parseContinue
    _ -> do
      expression <- parseExpression parseBlock
      pure (Located (locatedSpan expression) (ExpressionStatement expression))

{-| Reject a second statement written on the line a first one ended.

    A newline delimits a statement here, so `1 2` is not one expression and not
    two statements — it is two statements with the separator missing. Left
    unreported it silently became the second one, and `{ 1 2 }` evaluated to 2
    without a word. [[grammar/pudu]] requires `E1049`.

    A token that closes the block or ends the file is not a statement, and a
    continuation line is not one either — the continuation rule already decided
    that before this ever runs. -}
reportAdjacent :: Bool -> Parser Bool
reportAdjacent reported = do
  kind <- peekKind
  newLine <- peekStartsLine
  token <- peekToken
  if reported || isSymbol "}" kind || kind == EndOfFile || newLine
    then pure reported
    else do
      emitParseError "E1049" (tokenSpan token) "a statement ends at the line break"
        ( Just
            ( "put this on its own line; two statements on one line are not "
                <> "separated, and the language has no statement terminator"
            )
        )
      pure True

{-| `break [@label] [value]`.

    Both parts are optional and independent: `break` leaves the nearest loop,
    `break @outer` leaves the loop that label names, `break value` gives the
    nearest `loop` its result, and `break @outer value` does both. Whether the
    label exists and whether the loop can carry a value are semantic rules, not
    parsing ones. -}
parseBreak :: Parser (Located Statement)
parseBreak = do
  keyword <- advanceToken
  label <- parseLoopLabel
  value <- parseCarriedValue
  let ending = maybe (maybe (tokenSpan keyword) locatedSpan label) locatedSpan value
  pure (Located (mergedOrLeft (tokenSpan keyword) ending) (BreakStatement label value))

{-| `continue [@label]` never carries a value: it goes back to a loop that is
    about to run again, and there is nothing waiting to receive one. -}
parseContinue :: Parser (Located Statement)
parseContinue = do
  keyword <- advanceToken
  label <- parseLoopLabel
  let ending = maybe (tokenSpan keyword) locatedSpan label
  pure (Located (mergedOrLeft (tokenSpan keyword) ending) (ContinueStatement label))

{-| An `@name` immediately after `break` or `continue`, if one is written. -}
parseLoopLabel :: Parser (Maybe (Located Text))
parseLoopLabel = do
  kind <- peekKind
  newLine <- peekStartsLine
  if kind == Symbol SymAt && not newLine
    then do
      _ <- advanceToken
      Just <$> expectIdentifier "after @ to name the loop to leave"
    else pure Nothing

{-| The value a `break` carries, when one follows on the same line.

    The line rule is the same one `return` uses: a `break` alone on its line
    carries nothing, so a following statement is never swallowed as its
    value. -}
parseCarriedValue :: Parser (Maybe (Located Expression))
parseCarriedValue = do
  kind <- peekKind
  newLine <- peekStartsLine
  if isSymbol "}" kind || kind == EndOfFile || newLine
    then pure Nothing
    else Just <$> parseExpression parseBlock

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
