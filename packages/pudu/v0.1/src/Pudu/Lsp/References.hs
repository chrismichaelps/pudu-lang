{-| @Program.Lsp.References — finds all references to a symbol -}
module Pudu.Lsp.References (referencesAt) where

import Data.List (nub)
import Data.Text (Text)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (rangeOfOffsets, symbolAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Semantic.Resolve (Resolution (..))
import Pudu.Semantic.Symbol (Reference (..), Symbol (..))
import Pudu.Source (Span, spanEnd, spanStart, unOffset)

referencesAt :: Text -> Analysis -> Int -> Bool -> Json
referencesAt uri value offset includeDeclaration =
  case analysisResolution value >>= (\resolution -> (, resolution) <$> symbolAt resolution offset) of
    Nothing -> JsonArray []
    Just (symbol, resolution) ->
      let matchingRefs =
            [ referenceSpan reference
            | reference <- resolutionReferences resolution
            , referenceSymbol reference == symbolId symbol
            ]
          declSpans = if includeDeclaration then maybe [] pure (symbolSpan symbol) else []
          allSpans = nub (declSpans <> matchingRefs)
       in JsonArray (map (locationJson uri (analysisText value)) allSpans)

locationJson :: Text -> Text -> Span -> Json
locationJson uri content spanValue =
  JsonObject
    [ ("uri", JsonText uri)
    , ( "range"
      , rangeJson
          (rangeOfOffsets content (unOffset (spanStart spanValue)) (unOffset (spanEnd spanValue)))
      )
    ]
