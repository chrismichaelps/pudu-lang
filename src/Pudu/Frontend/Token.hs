{-| @Source.Token.Module — classifies lossless lexical units -}
module Pudu.Frontend.Token
  ( Keyword (..)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  , TemplatePart (..)
  , Trivia (..)
  , TriviaKind (..)
  , keywordFromText
  , keywordText
  , symbolFromText
  , symbolText
  ) where

import Data.Text (Text)
import Pudu.Source (Span)

{-| @Source.Token.Keyword — enumerates reserved language words -}
data Keyword
  = KwModule
  | KwImport
  | KwExport
  | KwAs
  | KwLet
  | KwVar
  | KwConst
  | KwMut
  | KwFn
  | KwAsync
  | KwReturn
  | KwIf
  | KwElse
  | KwMatch
  | KwCase
  | KwFor
  | KwIn
  | KwWhile
  | KwLoop
  | KwBreak
  | KwContinue
  | KwType
  | KwEnum
  | KwStruct
  | KwTrait
  | KwImpl
  | KwWhere
  | KwAwait
  | KwTask
  | KwSpawn
  | KwComptime
  | KwMacro
  | KwTrue
  | KwFalse
  | KwNull
  | KwUnsafe
  | KwWith
  | KwScope
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| @Source.Token.Symbol — enumerates admitted punctuation and operators -}
data SymbolKind
  = SymLeftParen
  | SymRightParen
  | SymLeftBracket
  | SymRightBracket
  | SymLeftBrace
  | SymRightBrace
  | SymComma
  | SymDot
  | SymColon
  | SymPipe
  | SymAssign
  | SymFatArrow
  | SymThinArrow
  | SymQuestion
  | SymBang
  | SymMinus
  | SymAmpersand
  | SymStar
  | SymSlash
  | SymPercent
  | SymPlus
  | SymWrapMultiply
  | SymSaturatingMultiply
  | SymWrapAdd
  | SymWrapSubtract
  | SymSaturatingAdd
  | SymSaturatingSubtract
  | SymRangeExclusive
  | SymRangeInclusive
  | SymLeftShift
  | SymRightShift
  | SymCaret
  | SymTilde
  | SymAt
  | SymLess
  | SymLessEqual
  | SymGreater
  | SymGreaterEqual
  | SymEqual
  | SymNotEqual
  | SymLogicalAnd
  | SymLogicalOr
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| @Source.Token.Kind — classifies one lexical unit -}
data TokenKind
  = Identifier !Text
  | IntegerLiteral !Text
  | FloatLiteral !Text
  | DecimalLiteral !Text
  | StringLiteral !Text
  | TemplateLiteral ![TemplatePart]
  | CharLiteral !Char
  | Keyword !Keyword
  | Symbol !SymbolKind
  | EndOfFile
  | Invalid !Text
  deriving stock (Eq, Show)

{-| @Source.Token.TemplatePart — one piece of an interpolated string.

    Text is already decoded, as an ordinary string literal's is. A hole carries
    the tokens between its braces, lexed by the same scanner as everything else
    and from the same source, so the expression the parser reads has real spans
    and a diagnostic inside an interpolation points at the interpolation. -}
data TemplatePart
  = TemplateText !Text
  | TemplateHole !Span ![Token]
  deriving stock (Eq, Show)

{-| @Source.Token.TriviaKind — classifies preserved non-semantic text.

    A doc comment is lexed as its own kind rather than recognized later by
    inspecting comment text: documentation is attached to the declaration that
    follows it, and deciding that from a prefix at every consumer would put the
    same rule in several places. -}
data TriviaKind = Whitespace | LineComment | BlockComment | DocComment
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| @Source.Token.Trivia — preserves comments and whitespace -}
data Trivia = Trivia
  { triviaKind :: !TriviaKind
  , triviaText :: !Text
  , triviaSpan :: !Span
  }
  deriving stock (Eq, Show)

{-| @Source.Token.Value — locates one lossless lexical unit -}
data Token = Token
  { tokenKind :: !TokenKind
  , tokenLexeme :: !Text
  , tokenSpan :: !Span
  , tokenLeadingTrivia :: ![Trivia]
  }
  deriving stock (Eq, Show)

keywordFromText :: Text -> Maybe Keyword
keywordFromText value = lookup value keywordMappings

keywordText :: Keyword -> Text
keywordText keyword =
  case keyword of
    KwModule -> "module"
    KwImport -> "import"
    KwExport -> "export"
    KwAs -> "as"
    KwLet -> "let"
    KwVar -> "var"
    KwConst -> "const"
    KwMut -> "mut"
    KwFn -> "fn"
    KwAsync -> "async"
    KwReturn -> "return"
    KwIf -> "if"
    KwElse -> "else"
    KwMatch -> "match"
    KwCase -> "case"
    KwFor -> "for"
    KwIn -> "in"
    KwWhile -> "while"
    KwLoop -> "loop"
    KwBreak -> "break"
    KwContinue -> "continue"
    KwType -> "type"
    KwEnum -> "enum"
    KwStruct -> "struct"
    KwTrait -> "trait"
    KwImpl -> "impl"
    KwWhere -> "where"
    KwAwait -> "await"
    KwTask -> "task"
    KwSpawn -> "spawn"
    KwComptime -> "comptime"
    KwMacro -> "macro"
    KwTrue -> "true"
    KwFalse -> "false"
    KwNull -> "null"
    KwUnsafe -> "unsafe"
    KwWith -> "with"
    KwScope -> "scope"

symbolFromText :: Text -> Maybe SymbolKind
symbolFromText value = lookup value symbolMappings

symbolText :: SymbolKind -> Text
symbolText symbol =
  case symbol of
    SymLeftParen -> "("
    SymRightParen -> ")"
    SymLeftBracket -> "["
    SymRightBracket -> "]"
    SymLeftBrace -> "{"
    SymRightBrace -> "}"
    SymComma -> ","
    SymDot -> "."
    SymColon -> ":"
    SymPipe -> "|"
    SymAssign -> "="
    SymFatArrow -> "=>"
    SymThinArrow -> "->"
    SymQuestion -> "?"
    SymBang -> "!"
    SymMinus -> "-"
    SymAmpersand -> "&"
    SymStar -> "*"
    SymSlash -> "/"
    SymPercent -> "%"
    SymPlus -> "+"
    SymWrapMultiply -> "&*"
    SymSaturatingMultiply -> "*|"
    SymWrapAdd -> "&+"
    SymWrapSubtract -> "&-"
    SymSaturatingAdd -> "+|"
    SymSaturatingSubtract -> "-|"
    SymRangeExclusive -> ".."
    SymRangeInclusive -> "..="
    SymLeftShift -> "<<"
    SymRightShift -> ">>"
    SymCaret -> "^"
    SymTilde -> "~"
    SymAt -> "@"
    SymLess -> "<"
    SymLessEqual -> "<="
    SymGreater -> ">"
    SymGreaterEqual -> ">="
    SymEqual -> "=="
    SymNotEqual -> "!="
    SymLogicalAnd -> "&&"
    SymLogicalOr -> "||"

keywordMappings :: [(Text, Keyword)]
keywordMappings = [(keywordText keyword, keyword) | keyword <- [minBound .. maxBound]]

symbolMappings :: [(Text, SymbolKind)]
symbolMappings = [(symbolText symbol, symbol) | symbol <- [minBound .. maxBound]]
