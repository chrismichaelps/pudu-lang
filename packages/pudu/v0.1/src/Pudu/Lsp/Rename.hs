{-| @Program.Lsp.Rename — prepares and performs symbol renames -}
module Pudu.Lsp.Rename
  ( prepareRenameAt
  , renameAt
  ) where

import Data.List (nub)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (rangeOfOffsets, symbolAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Semantic.Resolve (Resolution (..))
import Pudu.Semantic.Symbol (Reference (..), Symbol (..))
import Pudu.Source (spanEnd, spanStart, unOffset)

prepareRenameAt :: Analysis -> Int -> Json
prepareRenameAt value offset =
  case analysisResolution value >>= (\resolution -> symbolAt resolution offset) of
    Nothing -> JsonNull
    Just symbol -> case symbolSpan symbol of
      Nothing -> JsonNull
      Just definition ->
        let content = analysisText value
            range =
              rangeJson
                (rangeOfOffsets content (unOffset (spanStart definition)) (unOffset (spanEnd definition)))
         in JsonObject
              [ ("range", range)
              , ("placeholder", JsonText (symbolName symbol))
              ]

renameAt :: Text -> Analysis -> Int -> Text -> Json
renameAt uri value offset newName
  | Text.null (Text.strip newName) = JsonNull
  | otherwise =
      case analysisResolution value >>= (\resolution -> (, resolution) <$> symbolAt resolution offset) of
        Nothing -> JsonNull
        Just (symbol, resolution) ->
          let matchingRefs =
                [ referenceSpan reference
                | reference <- resolutionReferences resolution
                , referenceSymbol reference == symbolId symbol
                ]
              declSpans = maybe [] pure (symbolSpan symbol)
              allSpans = nub (declSpans <> matchingRefs)
              content = analysisText value
              edits =
                [ JsonObject
                    [ ( "range"
                      , rangeJson
                          (rangeOfOffsets content (unOffset (spanStart s)) (unOffset (spanEnd s)))
                      )
                    , ("newText", JsonText newName)
                    ]
                | s <- allSpans
                ]
           in JsonObject
                [ ("changes", JsonObject [(uri, JsonArray edits)])
                ]
