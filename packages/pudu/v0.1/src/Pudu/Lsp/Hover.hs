{-| @Program.Lsp.Hover — answers what an editor cursor is on -}
module Pudu.Lsp.Hover (hoverAt) where

import Control.Applicative ((<|>))
import Data.Char (isAlphaNum)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature
  ( entryForSymbol
  , hoverContents
  , rangeOfOffsets
  , symbolAt
  , wordSpanAt
  )
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Semantic.Resolve (Resolution (..))
import Pudu.Semantic.Symbol (Reference (..), Symbol (..))
import Pudu.Source (spanEnd, spanStart, unOffset)
import Pudu.Type (Type, narrowestSpanAt, renderType, widestWithin)

{-| The answer for the name under the cursor, and nothing when the cursor is
    not on a name.

    A keyword, an operator, or the space between words is inside some larger
    expression, but that expression is not what the reader pointed at: naming
    it after the word under the cursor would call `for` a `()`. -}
hoverAt :: Analysis -> Int -> Json
hoverAt value offset = case wordSpanAt (analysisText value) offset of
  Nothing -> JsonNull
  Just (word, (start, end)) -> case foreignNameAt value word offset of
    Just entry -> hoverEntry Nothing value entry
    Nothing -> case declaredAt value word offset of
      Just entry -> hoverEntry (Just (docSpan entry)) value entry
      Nothing -> case wordType value offset start end of
        Just typeValue -> typedHover word typeValue
        Nothing -> maybe JsonNull (hoverEntry Nothing value) (resolvedEntry value word offset)

foreignNameAt :: Analysis -> Text.Text -> Int -> Maybe DocEntry
foreignNameAt value word offset = do
  entry <- resolvedEntry value word offset
  case docKind entry of
    DocForeign _ -> Just entry
    _ -> Nothing

{-| The documented declaration the name under the cursor resolves to. A use
    whose span is wider than the name — a record literal around a field label —
    does not answer for the words inside it. -}
resolvedEntry :: Analysis -> Text.Text -> Int -> Maybe DocEntry
resolvedEntry value word offset = do
  resolution <- analysisResolution value
  symbol <- symbolAt resolution offset
  if symbolName symbol == word then Just () else Nothing
  entryForSymbol (analysisFileIndex value) symbol

{-| The documented declaration whose own name the cursor is on. -}
declaredAt :: Analysis -> Text.Text -> Int -> Maybe DocEntry
declaredAt value word offset =
  case [entry | entry <- indexEntries (analysisFileIndex value), docName entry == word, onName entry] of
    entry : _ -> Just entry
    [] -> Nothing
 where
  onName entry =
    let (start, end) = docSpan entry
        header = Text.takeWhile (/= '\n') (Text.drop start (Text.take end (analysisText value)))
        column = offset - start
     in case nameColumn word header of
          Just at -> at <= column && column <= at + Text.length word
          Nothing -> False

{-| Where a name first stands as a whole word in a line. -}
nameColumn :: Text.Text -> Text.Text -> Maybe Int
nameColumn word line =
  case [Text.length before | (before, after) <- Text.breakOnAll word line, standsAlone before (Text.drop (Text.length word) after)] of
    at : _ -> Just at
    [] -> Nothing
 where
  standsAlone before after =
    maybe True (not . nameScalar . snd) (Text.unsnoc before)
      && maybe True (not . nameScalar . fst) (Text.uncons after)
  nameScalar scalar = isAlphaNum scalar || scalar == '_'

{-| The type of the name under the cursor.

    The name itself may be an expression; otherwise the smallest expression
    ending with it — `Io.writeLine` for `writeLine` — is what it names. A
    binding that is never an expression where it is introduced has the type
    recorded where it is used. -}
wordType :: Analysis -> Int -> Int -> Int -> Maybe Type
wordType value offset start end = do
  info <- analysisTypes value
  widestWithin start end info
    <|> endingHere info
    <|> bindingType info
 where
  endingHere info = case narrowestSpanAt offset info of
    Just ((_, to), found) | to == end -> Just found
    _ -> Nothing
  bindingType info = do
    resolution <- analysisResolution value
    symbol <- symbolAt resolution offset
    definition <- symbolSpan symbol
    if unOffset (spanStart definition) <= offset && offset <= unOffset (spanEnd definition)
      then
        case [ found
             | reference <- resolutionReferences resolution
             , referenceSymbol reference == symbolId symbol
             , let spanValue = referenceSpan reference
             , Just found <- [widestWithin (unOffset (spanStart spanValue)) (unOffset (spanEnd spanValue)) info]
             ] of
          found : _ -> Just found
          [] -> Nothing
      else Nothing

typedHover :: Text.Text -> Type -> Json
typedHover word typeValue =
  JsonObject
    [ ( "contents"
      , JsonObject
          [ ("kind", JsonText "markdown")
          , ("value", JsonText (fenced (word <> " : " <> renderType typeValue)))
          ]
      )
    ]

hoverEntry :: Maybe (Int, Int) -> Analysis -> DocEntry -> Json
hoverEntry selected value entry =
  JsonObject
    ( [ ( "contents"
        , JsonObject [("kind", JsonText "markdown"), ("value", JsonText (hoverContents entry))]
        )
      ]
        <> case selected of
          Nothing -> []
          Just (start, end) ->
            [("range", rangeJson (rangeOfOffsets (analysisText value) start end))]
    )

fenced :: Text.Text -> Text.Text
fenced body = "```pudu\n" <> body <> "\n```"
