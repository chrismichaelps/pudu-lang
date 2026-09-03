{-| @Program.Lsp.Hover — answers what an editor cursor is on -}
module Pudu.Lsp.Hover (hoverAt) where

import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocKind (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature
  ( entryAt
  , entryForSymbol
  , hoverContents
  , rangeOfOffsets
  , symbolAt
  , wordAt
  )
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Type (narrowestAt, renderType)

hoverAt :: Analysis -> Int -> Json
hoverAt value offset = case foreignNameAt value offset of
  Just entry -> hoverEntry Nothing value entry
  Nothing -> case analysisTypes value >>= narrowestAt offset of
    Just typeValue ->
      JsonObject
        [ ( "contents"
          , JsonObject
              [ ("kind", JsonText "markdown")
              , ("value", JsonText (fenced (nameAt value offset <> renderType typeValue)))
              ]
          )
        ]
    Nothing -> case entryAt (analysisIndex value) offset of
      Nothing -> JsonNull
      Just entry -> hoverEntry (Just (docSpan entry)) value entry

foreignNameAt :: Analysis -> Int -> Maybe DocEntry
foreignNameAt value offset = do
  resolution <- analysisResolution value
  symbol <- symbolAt resolution offset
  entry <- entryForSymbol (analysisIndex value) symbol
  case docKind entry of
    DocForeign _ -> Just entry
    _ -> Nothing

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

nameAt :: Analysis -> Int -> Text.Text
nameAt value offset = case wordAt (analysisText value) offset of
  Just name | not (Text.null name) -> name <> " : "
  _ -> ""

fenced :: Text.Text -> Text.Text
fenced body = "```pudu\n" <> body <> "\n```"
