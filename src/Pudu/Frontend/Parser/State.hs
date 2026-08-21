{-| @Program.Parser.State — owns bounded token traversal -}
module Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , currentSpan
  , emitParseDiagnostic
  , emitParseError
  , expectIdentifier
  , expectKeyword
  , expectSymbol
  , isAtEnd
  , isDeclarationStart
  , isSymbol
  , initialParserState
  , lookaheadKind
  , matchKeyword
  , matchKind
  , matchSymbol
  , peekKind
  , peekToken
  , runParser
  , synchronizeDeclaration
  , withRecursionBudget
  ) where

import Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Data.Maybe (fromMaybe)
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  )
import Pudu.Frontend.Syntax.Located (Located (Located))
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwComptime, KwConst, KwEnum, KwExport, KwFn, KwImpl
    , KwLet, KwMacro, KwStruct, KwTrait, KwType, KwVar)
  , Token (..)
  , TokenKind (..)
  , keywordText
  , symbolFromText
  )
import Pudu.Source (Source, Span, emptySpan, sourceLength, zeroWidthSpan)

{-| @Program.Parser.State — isolates cursor and diagnostic invariants -}
data ParserState = ParserState
  { parserTokens :: !(Seq Token)
  , parserIndex :: !Int
  , parserDiagnosticsRev :: ![Diagnostic]
  , parserRecursionBudget :: !Int
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
        { parserTokens = normalizeTokens fallback tokens
        , parserIndex = 0
        , parserDiagnosticsRev = []
        , parserRecursionBudget = 512
        , parserFallbackEof = fallback
        }

runParser :: Source -> Parser a -> [Token] -> (a, [Diagnostic])
runParser source (Parser action) tokens =
  let (value, finalState) = action (initialParserState source tokens)
   in (value, sortDiagnostics (reverse (parserDiagnosticsRev finalState)))

peekToken :: Parser Token
peekToken = Parser $ \state -> (tokenAt 0 state, state)

peekKind :: Parser TokenKind
peekKind = tokenKind <$> peekToken

lookaheadKind :: Int -> Parser TokenKind
lookaheadKind distance = Parser $ \state -> (tokenKind (tokenAt distance state), state)

isAtEnd :: Parser Bool
isAtEnd = (== EndOfFile) <$> peekKind

advanceToken :: Parser Token
advanceToken = Parser $ \state ->
  let token = tokenAt 0 state
      nextIndex =
        if tokenKind token == EndOfFile
          then parserIndex state
          else min (parserIndex state + 1) (Seq.length (parserTokens state) - 1)
   in (token, state{parserIndex = nextIndex})

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

emitParseError :: Text -> Span -> Text -> Maybe Text -> Parser ()
emitParseError codeText spanValue message help =
  case parseDiagnostic codeText spanValue message help of
    Just value -> emitParseDiagnostic value
    Nothing -> pure ()

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
            diagnostics = maybe (parserDiagnosticsRev state) (: parserDiagnosticsRev state) finding
         in (Nothing, state{parserDiagnosticsRev = diagnostics})
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

expectedToken :: TokenKind -> Text -> Text -> Parser Token
expectedToken expected display context = do
  token <- peekToken
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
  let finalIndex = Seq.length (parserTokens state) - 1
      requested = min finalIndex (max 0 (parserIndex state + max 0 distance))
   in case Seq.lookup requested (parserTokens state) of
        Just token -> token
        Nothing -> parserFallbackEof state

normalizeTokens :: Token -> [Token] -> Seq Token
normalizeTokens fallback tokens =
  Seq.fromList $
    case break ((== EndOfFile) . tokenKind) tokens of
      (before, eof : _) -> before <> [eof]
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
