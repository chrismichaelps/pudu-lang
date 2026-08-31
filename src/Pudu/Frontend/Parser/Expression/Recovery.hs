{-| @Program.Parser.Expression.Recovery — bounded recovery for expression starts -}
module Pudu.Frontend.Parser.Expression.Recovery
  ( AmbiguityRecovery (..)
  , continuesAcrossLineBreak
  , invalidAtCurrent
  , invalidPrefix
  , isRecoveryBoundary
  , isPrefixCapableBinary
  , labelWithoutLoop
  , mergedOrLeft
  , parseCapabilityAnnotation
  , reportAmbiguousLineBreak
  , reservedKeywordGuidance
  , reservedPrefix
  , skipToLineBoundary
  , unaryOperators
  ) where

import Data.Text (Text)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , currentSpan
  , emitParseError
  , expectSymbol
  , isSymbol
  , matchSymbol
  , peekKind
  , peekStartsLine
  , peekToken
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Capability (..), Expression (..))
import Pudu.Frontend.Token
  ( Keyword (..)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  , symbolText
  )
import Pudu.Source (Span, mergeSpans)

data AmbiguityRecovery
  = PreserveStatement
  | RecoverOwner

{-| Parse the parenthesised capability list an `unsafe` region may carry.

    An absent list is not an empty one: writing no parentheses grants every
    capability, and writing `()` grants none, so the two cannot share a
    representation here. -}
parseCapabilityAnnotation :: Parser [Located Capability]
parseCapabilityAnnotation = do
  opening <- matchSymbol "("
  case opening of
    Nothing -> pure []
    Just _ -> do
      capabilities <- capabilityList []
      _ <- expectSymbol ")" "to close the capability list"
      pure capabilities

capabilityList :: [Located Capability] -> Parser [Located Capability]
capabilityList reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      capability <- oneCapability
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          let collected = maybe reversed (: reversed) capability
          case comma of
            Nothing -> pure (reverse collected)
            Just _ -> capabilityList collected

oneCapability :: Parser (Maybe (Located Capability))
oneCapability = do
  token <- advanceToken
  case capabilityFor (tokenKind token) of
    Just capability -> pure (Just (Located (tokenSpan token) capability))
    Nothing -> do
      emitParseError "E1044" (tokenSpan token) "unknown unsafe capability"
        (Just "name one of raw, foreign, unchecked, or null")
      pure Nothing

{-| The capability vocabulary is closed, so a misspelling is caught where it was
    written rather than becoming a grant of nothing. -}
capabilityFor :: TokenKind -> Maybe Capability
capabilityFor kind = case kind of
  Identifier "raw" -> Just RawCapability
  Identifier "foreign" -> Just ForeignCapability
  Identifier "unchecked" -> Just UncheckedCapability
  Keyword KwNull -> Just NullCapability
  _ -> Nothing

{-| A label that names no loop.

    Reported where the label was written rather than where the loop should have
    been, because the label is the part the reader can delete to make the
    program legal again. -}
labelWithoutLoop :: Token -> Parser (Located Expression)
labelWithoutLoop token = do
  emitParseError "E1053" (tokenSpan token) "label does not name a loop"
    (Just "write the label directly before `loop`, `while`, or `for`")
  skipToLineBoundary
  pure (Located (tokenSpan token) InvalidExpression)

{-| Recover where an expression was wanted and none could be read.

    A token the lexer marked `Invalid` has already been diagnosed, and
    precisely: `"{}"` is an interpolation with no expression, and `1.2.3` is a
    malformed number. Adding a generic "expected expression" over the top gives
    the reader two diagnostics for one mistake, with the less useful one first.
    Recovery still happens; only the second message goes. -}
invalidPrefix :: Token -> Parser (Located Expression)
invalidPrefix token = do
  case tokenKind token of
    Invalid _ -> pure ()
    _ ->
      emitParseError "E1040" (tokenSpan token) "expected expression"
        (Just "start with a literal, name, (, {, if, or unary operator")
  case tokenKind token of
    EndOfFile -> pure ()
    kind | isRecoveryBoundary kind -> pure ()
    _ -> advanceToken >> pure ()
  pure (Located (tokenSpan token) InvalidExpression)

{-| Reserved keywords that appear in expression position — typically because the
    REPL submits them as entries — produce a targeted diagnostic instead of the
    generic E1040. Each message points the reader toward the canonical form, so
    `enum`/`struct` point to `type`, `task`/`spawn` point to `async`/`scope`,
    `module` explains it is file-only, and `mut` points to `var`. -}
reservedKeywordGuidance :: Keyword -> Maybe Text
reservedKeywordGuidance keyword = case keyword of
  KwEnum -> Just "enum is reserved; use type for sum and record declarations"
  KwStruct -> Just "struct is reserved; use type for record declarations"
  KwTask -> Just "task is reserved; use async fn and scope for structured concurrency"
  KwSpawn -> Just "spawn is reserved; use async fn and scope for structured concurrency"
  KwModule -> Just "module declarations are only valid at the top of a file"
  KwMut -> Just "use var for mutable bindings; mut modifies references and fields"
  _ -> Nothing

reservedPrefix :: Token -> Text -> Parser (Located Expression)
reservedPrefix token guidance = do
  emitParseError "E1041" (tokenSpan token) "reserved keyword in expression position"
    (Just guidance)
  _ <- advanceToken
  skipToLineBoundary
  pure (Located (tokenSpan token) InvalidExpression)

{-| Diagnose the first prefix-capable spelling that could silently terminate a
    line-leading binary chain. Its expression owner chooses whether recovery
    preserves the token as a statement or advances to an enclosing delimiter. -}
reportAmbiguousLineBreak :: AmbiguityRecovery -> Parser ()
reportAmbiguousLineBreak recovery = do
  token <- peekToken
  emitParseError "E1055" (tokenSpan token)
    "this line can continue the expression or start a new one"
    ( Just
        ( "end the preceding line with "
            <> tokenText token
            <> " to continue, or "
            <> alternative
        )
    )
 where
  tokenText token = case tokenKind token of
    Symbol symbol -> symbolText symbol
    _ -> "the operator"
  alternative = case recovery of
    PreserveStatement ->
      "wrap this prefix expression in parentheses to start a new statement"
    RecoverOwner ->
      "rewrite the enclosing expression so this prefix expression is not adjacent to the chain"

{-| Consume the remaining tokens on the reserved keyword's line so a construct
    like `task my_task() -> Int { 42 }` reports one E1041 rather than a cascade
    of downstream parse errors. Recovery stops only at EOF or a line-initial
    token, never consuming the next line's first token. Closing delimiters and
    commas are skipped because they belong to the same line as the reserved
    keyword; stopping at them would leave trailing tokens that produce cascading
    errors. -}
skipToLineBoundary :: Parser ()
skipToLineBoundary = do
  kind <- peekKind
  case kind of
    EndOfFile -> pure ()
    _ -> do
      startsNewLine <- peekStartsLine
      if startsNewLine
        then pure ()
        else advanceToken >> skipToLineBoundary

invalidAtCurrent :: Parser (Located Expression)
invalidAtCurrent = currentSpan >>= \spanValue -> pure (Located spanValue InvalidExpression)

{-| Prefix position decides these: `&` and `*` are also binary operators, and
    the parser only consults this list where an operand is expected. -}
unaryOperators :: [SymbolKind]
unaryOperators = [SymBang, SymMinus, SymAmpersand, SymTilde, SymStar]

{-| A line-leading binary symbol continues exactly when it cannot instead be
    read as a prefix expression. -}
continuesAcrossLineBreak :: TokenKind -> Bool
continuesAcrossLineBreak kind = case kind of
  Symbol symbol -> symbol `notElem` unaryOperators
  Keyword KwIn -> True
  _ -> False

isPrefixCapableBinary :: TokenKind -> Bool
isPrefixCapableBinary kind = case kind of
  Symbol symbol -> symbol `elem` [SymMinus, SymAmpersand, SymStar]
  _ -> False

isRecoveryBoundary :: TokenKind -> Bool
isRecoveryBoundary kind = any (`isSymbol` kind) [",", ")", "]", "}"]

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
