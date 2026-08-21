module Pudu.Frontend.TokenSpec (tokenProperties) where

import Data.List (nub)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Token
  ( Keyword (KwWith)
  , SymbolKind
      ( SymAssign
      , SymDot
      , SymEqual
      , SymMinus
      , SymPlus
      , SymRangeExclusive
      , SymRangeInclusive
      , SymThinArrow
      )
  , Token (Token)
  , TokenKind
      ( CharLiteral, EndOfFile, FloatLiteral, Identifier
      , IntegerLiteral, Invalid, Keyword, StringLiteral, Symbol
      )
  , Trivia (Trivia)
  , TriviaKind (BlockComment, LineComment, Whitespace)
  , keywordFromText
  , keywordText
  , symbolFromText
  , symbolText
  , tokenKind
  , tokenLeadingTrivia
  , tokenLexeme
  , tokenSpan
  , triviaKind
  , triviaSpan
  , triviaText
  )
import Pudu.Source (Source, SourceName (SourceName), Span, mkSpan, newSource, offsetFromInt, sourceText)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

tokenProperties :: [(String, IO Property)]
tokenProperties =
  [ ("keyword vocabulary is exact", testKeywordVocabulary)
  , ("symbol vocabulary is exact", testSymbolVocabulary)
  , ("trivia vocabulary is exact", testTriviaVocabulary)
  , ("keyword and symbol lookup reject unknown text", testUnknownVocabulary)
  , ("token and leading trivia preserve source", testLosslessToken)
  , ("EOF can own trailing trivia", testTrailingTrivia)
  ]

testKeywordVocabulary :: IO Property
testKeywordVocabulary =
  pure
    ( conjoin
        [ keywordTexts === expectedKeywordTexts
        , property (length keywordTexts == length (nub keywordTexts))
        , property (all (\keyword -> keywordFromText (keywordText keyword) == Just keyword) allKeywords)
        , keywordFromText "with" === Just KwWith
        ]
    )

testTriviaVocabulary :: IO Property
testTriviaVocabulary =
  pure ([minBound .. maxBound] === [Whitespace, LineComment, BlockComment])

testSymbolVocabulary :: IO Property
testSymbolVocabulary =
  pure
    ( conjoin
        [ symbolTexts === expectedSymbolTexts
        , property (length symbolTexts == length (nub symbolTexts))
        , property (all (\symbol -> symbolFromText (symbolText symbol) == Just symbol) allSymbols)
        , map symbolFromText [".", "..", "..=", "-", "->", "=", "=="]
            === map Just [SymDot, SymRangeExclusive, SymRangeInclusive, SymMinus, SymThinArrow, SymAssign, SymEqual]
        ]
    )

testUnknownVocabulary :: IO Property
testUnknownVocabulary =
  pure
    ( conjoin
        [ keywordFromText Text.empty === Nothing
        , keywordFromText "mod" === Nothing
        , keywordFromText "Module" === Nothing
        , keywordFromText "WITH" === Nothing
        , keywordFromText "with " === Nothing
        , symbolFromText Text.empty === Nothing
        , symbolFromText "_" === Nothing
        , symbolFromText ";" === Nothing
        , symbolFromText "..." === Nothing
        ]
    )

testLosslessToken :: IO Property
testLosslessToken = do
  cases <- sequence
    [ losslessCase (Identifier "name") "name"
    , losslessCase (IntegerLiteral "42") "42"
    , losslessCase (FloatLiteral "1.5") "1.5"
    , losslessCase (StringLiteral "💡") "\"\\u{1F4A1}\""
    , losslessCase (CharLiteral 'x') "'x'"
    , losslessCase (Keyword KwWith) "with"
    , losslessCase (Symbol SymPlus) "+"
    , losslessCase (Invalid "@") "@"
    ]
  comments <- commentTriviaCase
  pure (conjoin (comments : cases))

losslessCase :: TokenKind -> Text -> IO Property
losslessCase kind lexeme = do
  source <- newSource (SourceName "token.pudu") (" " <> lexeme)
  pure $ case (spanAt source 0 1, spanAt source 1 (1 + Text.length lexeme)) of
    (Just leadingSpan, Just valueSpan) ->
      let leading = Trivia Whitespace " " leadingSpan
          value = Token kind lexeme valueSpan [leading]
       in conjoin
            [ tokenKind value === kind
            , tokenLexeme value === lexeme
            , tokenSpan value === valueSpan
            , tokenLeadingTrivia value === [leading]
            , reconstruct value === sourceText source
            ]
    _ -> counterexample "fixture span construction failed" False

commentTriviaCase :: IO Property
commentTriviaCase = do
  source <- newSource (SourceName "comments.pudu") "// note\n/* block */with"
  pure $ case (spanAt source 0 7, spanAt source 7 8, spanAt source 8 19, spanAt source 19 23) of
    (Just lineSpan, Just whitespaceSpan, Just blockSpan, Just valueSpan) ->
      let leading =
            [ Trivia LineComment "// note" lineSpan
            , Trivia Whitespace "\n" whitespaceSpan
            , Trivia BlockComment "/* block */" blockSpan
            ]
          value = Token (Keyword KwWith) "with" valueSpan leading
       in conjoin
            [ map triviaKind leading === [LineComment, Whitespace, BlockComment]
            , map triviaText leading === ["// note", "\n", "/* block */"]
            , map triviaSpan leading === [lineSpan, whitespaceSpan, blockSpan]
            , reconstruct value === sourceText source
            ]
    _ -> counterexample "comment fixture span construction failed" False

testTrailingTrivia :: IO Property
testTrailingTrivia = do
  source <- newSource (SourceName "eof.pudu") " "
  pure $ case (spanAt source 0 1, spanAt source 1 1) of
    (Just trailingSpan, Just eofSpan) ->
      let trailing = Trivia Whitespace " " trailingSpan
          eof = Token EndOfFile Text.empty eofSpan [trailing]
       in conjoin
            [ reconstruct eof === sourceText source
            , tokenLexeme eof === Text.empty
            , tokenKind eof === EndOfFile
            ]
    _ -> counterexample "fixture span construction failed" False

allKeywords :: [Keyword]
allKeywords = [minBound .. maxBound]
allSymbols :: [SymbolKind]
allSymbols = [minBound .. maxBound]
keywordTexts :: [Text]
keywordTexts = map keywordText allKeywords
symbolTexts :: [Text]
symbolTexts = map symbolText allSymbols

expectedKeywordTexts :: [Text]
expectedKeywordTexts =
  [ "module", "import", "export", "as", "let", "var", "const", "mut", "fn", "async"
  , "return", "if", "else", "match", "case", "for", "in", "while", "loop", "break"
  , "continue", "type", "enum", "struct", "trait", "impl", "where", "await", "task", "spawn"
  , "comptime", "macro", "true", "false", "null", "unsafe", "with", "scope"
  ]

expectedSymbolTexts :: [Text]
expectedSymbolTexts =
  [ "(", ")", "[", "]", "{", "}", ",", ".", ":", "|", "=", "->", "?", "!", "-"
  , "&", "*", "/", "%", "+", "&*", "*|", "&+", "&-", "+|", "-|", "..", "..=", "<"
  , "<=", ">", ">=", "==", "!=", "&&", "||"
  ]

reconstruct :: Token -> Text
reconstruct token = Text.concat (map triviaText (tokenLeadingTrivia token)) <> tokenLexeme token

spanAt :: Source -> Int -> Int -> Maybe Span
spanAt source start end = do
  startOffset <- offsetFromInt start
  endOffset <- offsetFromInt end
  mkSpan source startOffset endOffset
