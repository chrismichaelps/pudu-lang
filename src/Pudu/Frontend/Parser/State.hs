{-| @Program.Parser.State — owns bounded token traversal -}
module Pudu.Frontend.Parser.State
  ( BlockParser
  , Parser
  , advanceToken
  , budgetExhausted
  , currentSpan
  , emitParseDiagnostic
  , diagnosticCount
  , emitParseError
  , expectIdentifier
  , expectKeyword
  , expectSymbol
  , isAtEnd
  , isDeclarationStart
  , isSymbol
  , initialParserState
  , lookaheadKind
  , matchingBracketDistance
  , matchKeyword
  , matchKind
  , matchSymbol
  , peekKind
  , peekStartsLine
  , recordsAdmitted
  , peekToken
  , runParser
  , synchronizeDeclaration
  , withRecordAdmission
  , withRecursionBudget
  , withTokens
  ) where

import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  )
import Pudu.Frontend.Syntax.Located (Located (Located))
import Pudu.Frontend.Syntax.Tree (Block)
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwComptime, KwConst, KwEnum, KwExport, KwFn, KwImpl
    , KwLet, KwMacro, KwStruct, KwTrait, KwType, KwVar)
  , Token (..)
  , TokenKind (..)
  , Trivia (triviaText)
  , keywordText
  , symbolFromText
  )
import Pudu.Source (Source, Span, emptySpan, sourceLength, zeroWidthSpan)

{-| @Parser.State.BlockParser — the capability of reading a brace-delimited block.

    Blocks, expressions, and declarations are mutually recursive, and this alias
    is what lets each of them accept the others as an argument instead of
    importing them. It lives here rather than with any one of them because a
    shared capability that lived in one participant would put that participant
    in every cycle it exists to break. -}
type BlockParser = Parser (Located Block)

{-| @Program.Parser.State — isolates cursor and diagnostic invariants -}
data ParserState = ParserState
  { parserRemaining :: ![Token]
  , parserDiagnosticsRev :: ![Diagnostic]
  , parserRecursionBudget :: !Int
  , parserBudgetExhausted :: !Bool
  , parserAdmitsRecords :: !Bool
  , parserFallbackEof :: !Token
  }

{-| @Program.Parser.Action — threads opaque parser state -}
newtype Parser a = Parser (ParserState -> (a, ParserState))

instance Functor Parser where
  fmap transform (Parser action) =
    Parser $ \state ->
      let (value, next) = action state
       in (transform value, next)

instance Applicative Parser where
  pure value = Parser (\state -> (value, state))
  Parser functionAction <*> Parser valueAction =
    Parser $ \state ->
      let (functionValue, afterFunction) = functionAction state
          (value, afterValue) = valueAction afterFunction
       in (functionValue value, afterValue)

instance Monad Parser where
  Parser action >>= continue =
    Parser $ \state ->
      let (value, afterValue) = action state
          Parser nextAction = continue value
       in nextAction afterValue

initialParserState :: Source -> [Token] -> ParserState
initialParserState source tokens =
  let fallback = sourceEof source
   in ParserState
        { parserRemaining = normalizeTokens fallback tokens
        , parserDiagnosticsRev = []
        , parserRecursionBudget = 512
        , parserBudgetExhausted = False
        , parserAdmitsRecords = True
        , parserFallbackEof = fallback
        }

runParser :: Source -> Parser a -> [Token] -> (a, [Diagnostic])
runParser source (Parser action) tokens =
  let (value, finalState) = action (initialParserState source tokens)
   in (value, sortDiagnostics (reverse (parserDiagnosticsRev finalState)))

{-| Parse a separate token stream, then resume where the caller was.

    An interpolation's expression was lexed by the same scanner into tokens of
    its own; reading it needs the ordinary expression parser pointed at those
    tokens rather than at the stream the caller is in. Diagnostics recorded
    inside are kept, because a mistake inside an interpolation is a mistake in
    the program. -}
withTokens :: [Token] -> Parser a -> Parser a
withTokens tokens (Parser action) =
  Parser $ \state ->
    let nested =
          state
            { parserRemaining = normalizeTokens (parserFallbackEof state) tokens
            , parserBudgetExhausted = False
            }
        (value, after) = action nested
     in (value, state{parserDiagnosticsRev = parserDiagnosticsRev after})

peekToken :: Parser Token
peekToken = Parser $ \state -> (tokenAt 0 state, state)

{-| Line significance is answered from preserved leading trivia. No terminator
    token is synthesized, so lossless reconstruction stays intact. -}
peekStartsLine :: Parser Bool
peekStartsLine = startsLine <$> peekToken

startsLine :: Token -> Bool
startsLine = any (Text.any isLineBreak . triviaText) . tokenLeadingTrivia
 where
  isLineBreak character = character == '\n' || character == '\r'

peekKind :: Parser TokenKind
peekKind = tokenKind <$> peekToken

{-| How many tokens ahead the bracket opening here closes, or nothing when it
    does not close before the stream ends.

    A type-argument list and an index both open with `[`, and only what follows
    the closing bracket tells them apart. -}
matchingBracketDistance :: Parser (Maybe Int)
matchingBracketDistance = Parser $ \state -> (scan 0 (0 :: Int) state, state)
 where
  scan distance depth state
    | distance > 256 = Nothing
    | otherwise = case tokenKind (tokenAt distance state) of
        EndOfFile -> Nothing
        kind
          | isSymbol "[" kind -> scan (distance + 1) (depth + 1) state
          | isSymbol "]" kind ->
              if depth <= 1 then Just distance else scan (distance + 1) (depth - 1) state
          | otherwise -> scan (distance + 1) depth state

lookaheadKind :: Int -> Parser TokenKind
lookaheadKind distance = Parser $ \state -> (tokenKind (tokenAt distance state), state)

isAtEnd :: Parser Bool
isAtEnd = (== EndOfFile) <$> peekKind

advanceToken :: Parser Token
advanceToken = Parser $ \state ->
  let token = tokenAt 0 state
      remaining = case parserRemaining state of
        current : rest | tokenKind current /= EndOfFile -> rest
        _ -> parserRemaining state
   in (token, state{parserRemaining = remaining})

matchKind :: (TokenKind -> Bool) -> Parser (Maybe Token)
matchKind predicate = do
  token <- peekToken
  if predicate (tokenKind token)
    then Just <$> advanceToken
    else pure Nothing

matchKeyword :: Keyword -> Parser (Maybe Token)
matchKeyword expected = matchKind (== Keyword expected)

isSymbol :: Text -> TokenKind -> Bool
isSymbol expected kind = maybe False (\symbol -> kind == Symbol symbol) (symbolFromText expected)

matchSymbol :: Text -> Parser (Maybe Token)
matchSymbol expected = matchKind (isSymbol expected)

expectKeyword :: Keyword -> Text -> Parser Token
expectKeyword expected context = do
  matched <- matchKeyword expected
  case matched of
    Just token -> pure token
    Nothing -> expectedToken (Keyword expected) (keywordText expected) context

expectSymbol :: Text -> Text -> Parser Token
expectSymbol expected context = do
  matched <- matchSymbol expected
  case matched of
    Just token -> pure token
    Nothing ->
      expectedToken
        (maybe (Invalid expected) Symbol (symbolFromText expected))
        expected
        context

expectIdentifier :: Text -> Parser (Located Text)
expectIdentifier context = do
  token <- peekToken
  case tokenKind token of
    Identifier name -> do
      _ <- advanceToken
      pure (Located (tokenSpan token) name)
    _ -> do
      synthetic <- expectedToken (Identifier "") "identifier" context
      pure (Located (tokenSpan synthetic) "")

emitParseDiagnostic :: Diagnostic -> Parser ()
emitParseDiagnostic value =
  Parser $ \state ->
    ((), state{parserDiagnosticsRev = value : parserDiagnosticsRev state})

{-| How many diagnostics this parse has produced so far.

    A recovery rule that only makes sense on otherwise-clean input reads this
    to stay quiet once something has already gone wrong, which is what keeps a
    hostile file from turning one mistake into hundreds. -}
diagnosticCount :: Parser Int
diagnosticCount = Parser $ \state -> (length (parserDiagnosticsRev state), state)

{-| Report a parse error, unless the nesting budget has already been exhausted.

    Once the budget is gone the parse has given up, and every message after that
    describes the wreckage rather than the mistake. Without this an input of
    five thousand nested parentheses reported one `E1099` and then four and a
    half thousand `E1001`s as recovery unwound past each unmatched delimiter —
    one hostile file amplified into thousands of diagnostics. -}
emitParseError :: Text -> Span -> Text -> Maybe Text -> Parser ()
emitParseError codeText spanValue message help = do
  exhausted <- budgetExhausted
  if exhausted
    then pure ()
    else case parseDiagnostic codeText spanValue message help of
      Just value -> emitParseDiagnostic value
      Nothing -> pure ()

{-| Whether a record construction may start here. It is withheld only for the
    expression that precedes a block, where `Name {` would be ambiguous with the
    block itself, and is reinstated inside any bracketed context. -}
recordsAdmitted :: Parser Bool
recordsAdmitted = Parser $ \state -> (parserAdmitsRecords state, state)

withRecordAdmission :: Bool -> Parser a -> Parser a
withRecordAdmission admitted (Parser action) =
  Parser $ \state ->
    let (value, next) = action state{parserAdmitsRecords = admitted}
     in (value, next{parserAdmitsRecords = parserAdmitsRecords state})

{-| Whether the shared nesting budget has already been exhausted during this
    parse. Grammar loops stop instead of re-descending, so one hostile input
    reports exactly one `E1099` and no unwinding delimiter cascade. -}
budgetExhausted :: Parser Bool
budgetExhausted = Parser $ \state -> (parserBudgetExhausted state, state)

currentSpan :: Parser Span
currentSpan = tokenSpan <$> peekToken

withRecursionBudget :: Parser a -> Parser (Maybe a)
withRecursionBudget (Parser action) =
  Parser $ \state ->
    if parserRecursionBudget state <= 0
      then
        let token = tokenAt 0 state
            finding = parseDiagnostic "E1099" (tokenSpan token) "parser nesting limit exceeded"
              (Just "simplify the nested expression or split it into smaller declarations")
            diagnostics
              | parserBudgetExhausted state = parserDiagnosticsRev state
              | otherwise = maybe (parserDiagnosticsRev state) (: parserDiagnosticsRev state) finding
         in (Nothing, state{parserDiagnosticsRev = diagnostics, parserBudgetExhausted = True})
      else
        let reduced = state{parserRecursionBudget = parserRecursionBudget state - 1}
            (value, afterAction) = action reduced
            restored = afterAction{parserRecursionBudget = parserRecursionBudget state}
         in (Just value, restored)

synchronizeDeclaration :: Parser ()
synchronizeDeclaration = do
  kind <- peekKind
  case kind of
    EndOfFile -> pure ()
    _ | isSymbol "}" kind -> pure ()
    _ -> do
      _ <- advanceToken
      seekBoundary
 where
  seekBoundary = do
    kind <- peekKind
    if kind == EndOfFile || isSymbol "}" kind || isDeclarationStart kind
      then pure ()
      else advanceToken >> seekBoundary

{-| Report what was wanted where it was not found.

    A file that simply ran out is not the same mistake as a wrong token, and it
    reads differently: `expected }` against the last line of a file tells the
    reader nothing about which brace, while naming the end of input says the
    construct was never closed at all. [[grammar/pudu]] gives the second case
    its own code. -}
expectedToken :: TokenKind -> Text -> Text -> Parser Token
expectedToken expected display context = do
  token <- peekToken
  if tokenKind token == EndOfFile
    then
      emitParseError "E1000" (tokenSpan token) ("the file ends before " <> display)
        (Just ("add " <> display <> " " <> context <> "; the construct is never closed"))
    else
      emitParseError "E1001" (tokenSpan token) ("expected " <> display)
        (Just ("add " <> display <> " " <> context))
  pure
    Token
      { tokenKind = expected
      , tokenLexeme = ""
      , tokenSpan = tokenSpan token
      , tokenLeadingTrivia = []
      }

tokenAt :: Int -> ParserState -> Token
tokenAt distance state =
  seek (max 0 distance) (parserRemaining state)
  where
    seek remaining tokens = case tokens of
      token : rest
        | remaining > 0 && tokenKind token /= EndOfFile -> seek (remaining - 1) rest
        | otherwise -> token
      [] -> parserFallbackEof state

normalizeTokens :: Token -> [Token] -> [Token]
normalizeTokens fallback tokens =
  case break ((== EndOfFile) . tokenKind) tokens of
    (before, eof : _) -> before <> [fallback{tokenLeadingTrivia = tokenLeadingTrivia eof}]
    (before, []) -> before <> [fallback]

sourceEof :: Source -> Token
sourceEof source =
  Token
    { tokenKind = EndOfFile
    , tokenLexeme = ""
    , tokenSpan = fromMaybe (emptySpan source) (zeroWidthSpan source (sourceLength source))
    , tokenLeadingTrivia = []
    }

isDeclarationStart :: TokenKind -> Bool
isDeclarationStart kind =
  case kind of
    Keyword keyword -> keyword `elem`
      [ KwExport, KwLet, KwVar, KwConst, KwFn, KwAsync, KwType, KwEnum
      , KwStruct, KwTrait, KwImpl, KwComptime, KwMacro
      ]
    _ -> False

parseDiagnostic :: Text -> Span -> Text -> Maybe Text -> Maybe Diagnostic
parseDiagnostic codeText spanValue message help = do
  code <- mkDiagnosticCode codeText
  base <- diagnostic code Error spanValue message
  pure (maybe base (\helpText -> withHelp helpText base) help)
