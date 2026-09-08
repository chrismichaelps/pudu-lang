{-| @Program.Lsp.Highlight — highlights occurrences of the symbol under cursor -}
module Pudu.Lsp.Highlight (documentHighlightAt) where

import Data.List (nub)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (rangeOfOffsets, symbolAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Semantic.Resolve (Resolution (..))
import Pudu.Semantic.Symbol (Reference (..), Symbol (..))
import Pudu.Source (Span, spanEnd, spanStart, unOffset)

import Data.Text (Text)

documentHighlightAt :: Analysis -> Int -> Json
documentHighlightAt value offset =
  case analysisResolution value >>= (\resolution -> (, resolution) <$> symbolAt resolution offset) of
    Nothing -> JsonArray []
    Just (symbol, resolution) ->
      let content = analysisText value
          matchingRefs =
            [ (referenceSpan reference, 2)
            | reference <- resolutionReferences resolution
            , referenceSymbol reference == symbolId symbol
            ]
          declItems = case symbolSpan symbol of
            Just definition -> [(definition, 3)]
            Nothing -> []
          allSpans = nub (declItems <> matchingRefs)
       in JsonArray (map (highlightJson content) allSpans)

highlightJson :: Text -> (Span, Int) -> Json
highlightJson content (spanValue, kind) =
  JsonObject
    [ ( "range"
      , rangeJson
          (rangeOfOffsets content (unOffset (spanStart spanValue)) (unOffset (spanEnd spanValue)))
      )
    , ("kind", JsonNumber (fromIntegral kind))
    ]
