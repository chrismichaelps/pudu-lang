{-| @Program.Lsp.Feature.Module — what the editor shows, from the index -}
module Pudu.Lsp.Feature
  ( completionItems
  , documentSymbols
  , entryAt
  , hoverContents
  , locationOf
  , offsetAt
  , positionAt
  , rangeOfOffsets
  , entryForSymbol
  , symbolAt
  , wordAt
  ) where

import Data.Char (isAlphaNum)
import Data.List (sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Doc.Signature (renderSignature)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (Position (..), Range (..), rangeJson)
import Pudu.Semantic.Resolve (Resolution (..))
import Pudu.Semantic.Symbol (Reference (..), Symbol (..))
import Pudu.Source (Span, spanEnd, spanStart, unOffset)

{-| The offset in scalars that an editor position names.

    The protocol counts a line's offset in **UTF-16 code units**, not scalars,
    which differ the moment a file holds anything outside the basic plane: a
    cursor after one emoji reports character 2. Reading it as a scalar count
    would land one position early and grow worse with every astral scalar on the
    line, so the conversion is done here, once, at the edge. -}
offsetAt :: Text -> Position -> Int
offsetAt content position = lineStart + withinLine
 where
  lines' = Text.splitOn "\n" content
  before = take (positionLine position) lines'
  lineStart = sum (map ((+ 1) . Text.length) before)
  line = case drop (positionLine position) lines' of
    current : _ -> current
    [] -> Text.empty
  withinLine = scalarsForUnits (positionCharacter position) line

{-| How many scalars a count of UTF-16 code units covers. -}
scalarsForUnits :: Int -> Text -> Int
scalarsForUnits wanted = go 0 0
 where
  go scalars units rest
    | units >= wanted = scalars
    | otherwise = case Text.uncons rest of
        Nothing -> scalars
        Just (scalar, remaining) -> go (scalars + 1) (units + utf16Width scalar) remaining

utf16Width :: Char -> Int
utf16Width scalar = if fromEnum scalar > 0xFFFF then 2 else 1

{-| The editor position a scalar offset names, the inverse of `offsetAt`. -}
positionAt :: Text -> Int -> Position
positionAt content offset = Position line character
 where
  before = Text.take offset content
  line = Text.count "\n" before
  lastLine = case Text.breakOnEnd "\n" before of
    (_, after) -> after
  character = Text.foldl' (\total scalar -> total + utf16Width scalar) 0 lastLine

rangeOfOffsets :: Text -> Int -> Int -> Range
rangeOfOffsets content start end =
  Range (positionAt content start) (positionAt content (max start end))

{-| The documented name whose span covers an offset.

    The narrowest one wins. A declaration's span encloses its members' spans, so
    the widest match is always the enclosing declaration and would answer every
    hover with the same thing. -}
entryAt :: DocIndex -> Int -> Maybe DocEntry
entryAt index offset =
  case sortOn width [entry | entry <- indexEntries index, covers entry] of
    entry : _ -> Just entry
    [] -> Nothing
 where
  covers entry =
    let (start, end) = docSpan entry
     in offset >= start && offset <= end
  width entry = let (start, end) = docSpan entry in end - start

{-| The resolved declaration or reference under a scalar offset. -}
symbolAt :: Resolution -> Int -> Maybe Symbol
symbolAt resolution offset = do
  identifier <- case [referenceSymbol reference | reference <- resolutionReferences resolution
    , coversSpan offset (referenceSpan reference)] of
      found : _ -> Just found
      [] -> symbolId <$> firstCovering (resolutionSymbols resolution)
  firstMatching identifier (resolutionSymbols resolution)
 where
  firstCovering symbols = case [symbol | symbol <- symbols
    , maybe False (coversSpan offset) (symbolSpan symbol)] of
      found : _ -> Just found
      [] -> Nothing
  firstMatching identifier symbols = case [symbol | symbol <- symbols, symbolId symbol == identifier] of
    found : _ -> Just found
    [] -> Nothing

{-| The documentation entry belonging to one resolved declaration symbol. -}
entryForSymbol :: DocIndex -> Symbol -> Maybe DocEntry
entryForSymbol index symbol = do
  definition <- symbolSpan symbol
  let start = unOffset (spanStart definition)
      candidates =
        [ entry
        | entry <- indexEntries index
        , docName entry == symbolName symbol
        , let (entryStart, entryEnd) = docSpan entry
        , start >= entryStart && start <= entryEnd
        ]
  case sortOn entryWidth candidates of
    found : _ -> Just found
    [] -> Nothing
 where
  entryWidth entry = let (start, end) = docSpan entry in end - start

coversSpan :: Int -> Span -> Bool
coversSpan offset spanValue =
  offset >= unOffset (spanStart spanValue) && offset <= unOffset (spanEnd spanValue)

{-| The identifier the cursor is inside, which is what a reader asking for a
    definition is pointing at. -}
wordAt :: Text -> Int -> Maybe Text
wordAt content offset
  | Text.null found = Nothing
  | otherwise = Just found
 where
  before = Text.takeWhileEnd wordScalar (Text.take offset content)
  after = Text.takeWhile wordScalar (Text.drop offset content)
  found = before <> after
  wordScalar scalar = isAlphaNum scalar || scalar == '_'

{-| What a hover shows: the signature first, then the documentation.

    The signature is the answer to "what is this", and the prose is the answer
    to "why". A reader who already knows the second still wants the first, and
    putting it first means they do not have to read past a paragraph to find
    it. -}
hoverContents :: DocEntry -> Text
hoverContents entry =
  Text.intercalate "\n\n" ([signatureBlock] <> documentation <> [origin])
 where
  signatureBlock =
    "```pudu\n" <> docName entry <> signatureSuffix <> "\n```"
  signatureSuffix = case docSignature entry of
    Nothing -> Text.empty
    Just value -> " : " <> renderSignature value
  documentation =
    [Text.intercalate "\n" (docComment entry) | not (null (docComment entry))]
  origin = "*" <> kindText (docKind entry) <> " in `" <> docModule entry <> "`*"

kindText :: DocKind -> Text
kindText kind = case kind of
  DocFunction -> "function"
  DocTraitMethod owner -> "method of trait " <> owner
  DocMethod owner -> "method of " <> owner
  DocConstant -> "constant"
  DocType -> "type"
  DocTrait -> "trait"
  DocMacro -> "macro"
  DocForeign library -> "foreign function from " <> library <> ", asserted rather than proved"

locationOf :: Text -> Text -> DocEntry -> Json
locationOf uri content entry =
  JsonObject
    [ ("uri", JsonText uri)
    , ("range", rangeJson (rangeOfOffsets content start end))
    ]
 where
  (start, end) = docSpan entry

{-| Every documented name in the file, as the outline an editor draws.

    Flat rather than nested: the index records what a module declares, and
    inventing a hierarchy the index does not have would put members under
    whichever declaration happened to enclose them by offset. -}
documentSymbols :: Text -> DocIndex -> Json
documentSymbols content index = JsonArray (map symbol (indexEntries index))
 where
  symbol entry =
    let (start, end) = docSpan entry
        span' = rangeJson (rangeOfOffsets content start end)
     in JsonObject
          [ ("name", JsonText (docName entry))
          , ("detail", JsonText (detailOf entry))
          , ("kind", JsonNumber (fromIntegral (symbolKind (docKind entry))))
          , ("range", span')
          , ("selectionRange", span')
          ]

detailOf :: DocEntry -> Text
detailOf entry = case docSignature entry of
  Nothing -> Text.empty
  Just value -> renderSignature value

{-| The protocol's symbol numbers. A method is reported as a method rather than
    a function so an editor's outline groups it the way the reader wrote it. -}
symbolKind :: DocKind -> Int
symbolKind kind = case kind of
  DocFunction -> 12
  DocTraitMethod _ -> 6
  DocMethod _ -> 6
  DocConstant -> 14
  DocType -> 23
  DocTrait -> 11
  DocMacro -> 12
  DocForeign _ -> 12

{-| Everything the file declares, offered as completions.

    The detail is the signature and the documentation travels with it, so the
    editor's completion list answers "what is this" without a second request.
    Ordering is left to the client, which knows what the reader has typed. -}
completionItems :: DocIndex -> Json
completionItems index = JsonArray (map item (indexEntries index))
 where
  item entry =
    JsonObject
      [ ("label", JsonText (docName entry))
      , ("kind", JsonNumber (fromIntegral (completionKind (docKind entry))))
      , ("detail", JsonText (detailOf entry))
      , ( "documentation"
        , JsonObject
            [ ("kind", JsonText "markdown")
            , ("value", JsonText (Text.intercalate "\n" (docComment entry)))
            ]
        )
      ]

completionKind :: DocKind -> Int
completionKind kind = case kind of
  DocFunction -> 3
  DocTraitMethod _ -> 2
  DocMethod _ -> 2
  DocConstant -> 21
  DocType -> 22
  DocTrait -> 8
  DocMacro -> 3
  DocForeign _ -> 3
