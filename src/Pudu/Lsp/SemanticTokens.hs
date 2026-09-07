{-| @Program.Lsp.SemanticTokens — full document semantic tokens -}
module Pudu.Lsp.SemanticTokens
  ( semanticTokensLegend
  , semanticTokensFull
  ) where

import Data.Char (isUpper)
import Data.List (sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocKind (..))
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Token
  ( Token (..)
  , TokenKind (..)
  , Trivia (..)
  , TriviaKind (..)
  )
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (entryForSymbol, positionAt, symbolAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (Position (..))
import qualified Pudu.Semantic.Symbol as Sym
import Pudu.Source (Span, spanEnd, spanStart, unOffset)

semanticTokensLegend :: Json
semanticTokensLegend =
  JsonObject
    [ ( "tokenTypes"
      , JsonArray (map JsonText legendTypes)
      )
    , ( "tokenModifiers"
      , JsonArray (map JsonText legendModifiers)
      )
    ]

legendTypes :: [Text]
legendTypes =
  [ "type"
  , "class"
  , "function"
  , "method"
  , "variable"
  , "parameter"
  , "property"
  , "keyword"
  , "comment"
  , "string"
  , "number"
  , "operator"
  ]

legendModifiers :: [Text]
legendModifiers =
  [ "declaration"
  , "definition"
  , "readonly"
  , "defaultLibrary"
  ]

semanticTokensFull :: Analysis -> Json
semanticTokensFull value =
  let LexResult tokens _ = lexSource (analysisSource value)
      content = analysisText value
      rawItems = concatMap (classifyToken value content) tokens
      sortedItems = sortOn (\(l, c, _, _, _) -> (l, c)) rawItems
      encoded = deltaEncode 0 0 sortedItems
   in JsonObject [("data", JsonArray (map (JsonNumber . fromIntegral) encoded))]

classifyToken :: Analysis -> Text -> Token -> [(Int, Int, Int, Int, Int)]
classifyToken value content tok =
  triviaItems <> tokenItem
 where
  triviaItems = concatMap (classifyTrivia content) (tokenLeadingTrivia tok)
  tokenItem = case tokenKind tok of
    EndOfFile -> []
    Invalid _ -> []
    Keyword _ -> [spanTuple content (tokenSpan tok) 7 0]
    IntegerLiteral _ -> [spanTuple content (tokenSpan tok) 10 0]
    FloatLiteral _ -> [spanTuple content (tokenSpan tok) 10 0]
    DecimalLiteral _ -> [spanTuple content (tokenSpan tok) 10 0]
    StringLiteral _ -> [spanTuple content (tokenSpan tok) 9 0]
    TemplateLiteral _ -> [spanTuple content (tokenSpan tok) 9 0]
    CharLiteral _ -> [spanTuple content (tokenSpan tok) 9 0]
    Symbol _ -> [spanTuple content (tokenSpan tok) 11 0]
    Identifier name -> [classifyIdentifier value content (tokenSpan tok) name]

classifyTrivia :: Text -> Trivia -> [(Int, Int, Int, Int, Int)]
classifyTrivia content tr = case triviaKind tr of
  Whitespace -> []
  LineComment -> [spanTuple content (triviaSpan tr) 8 0]
  BlockComment -> [spanTuple content (triviaSpan tr) 8 0]
  DocComment -> [spanTuple content (triviaSpan tr) 8 0]

classifyIdentifier :: Analysis -> Text -> Span -> Text -> (Int, Int, Int, Int, Int)
classifyIdentifier value content sp name =
  case analysisResolution value >>= (\resolution -> symbolAt resolution (unOffset (spanStart sp))) of
    Just symbol ->
      let isDecl = maybe False (\s -> spanStart s == spanStart sp) (Sym.symbolSpan symbol)
          mods = if isDecl then 1 else 0
       in case entryForSymbol (analysisIndex value) symbol of
            Just entry -> case docKind entry of
              DocFunction -> spanTuple content sp 2 mods
              DocMethod _ -> spanTuple content sp 3 mods
              DocTraitMethod _ -> spanTuple content sp 3 mods
              DocType -> spanTuple content sp 0 mods
              DocTrait -> spanTuple content sp 1 mods
              DocConstant -> spanTuple content sp 4 (mods + 4)
              DocForeign _ -> spanTuple content sp 2 mods
              DocMacro -> spanTuple content sp 2 mods
            Nothing
              | startsWithUpper name -> spanTuple content sp 0 mods
              | otherwise -> spanTuple content sp 4 mods
    Nothing
      | startsWithUpper name -> spanTuple content sp 0 0
      | otherwise -> spanTuple content sp 4 0

startsWithUpper :: Text -> Bool
startsWithUpper text = case Text.uncons text of
  Just (char, _) -> isUpper char
  Nothing -> False

spanTuple :: Text -> Span -> Int -> Int -> (Int, Int, Int, Int, Int)
spanTuple content sp tokenType modifiers =
  let startOffset = unOffset (spanStart sp)
      endOffset = unOffset (spanEnd sp)
      Position line char = positionAt content startOffset
      len = max 1 (endOffset - startOffset)
   in (line, char, len, tokenType, modifiers)

deltaEncode :: Int -> Int -> [(Int, Int, Int, Int, Int)] -> [Int]
deltaEncode _ _ [] = []
deltaEncode prevLine prevChar ((line, char, len, tokenType, modifiers) : rest) =
  let deltaLine = line - prevLine
      deltaChar = if deltaLine == 0 then char - prevChar else char
   in deltaLine : deltaChar : len : tokenType : modifiers : deltaEncode line char rest
