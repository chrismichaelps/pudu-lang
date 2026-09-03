{-| @Program.Lsp.Definition — locates the declaration named at a cursor -}
module Pudu.Lsp.Definition (definitionAt) where

import Data.Text (Text)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (rangeOfOffsets, symbolAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Semantic.Symbol (Symbol (..))
import Pudu.Source (spanEnd, spanStart, unOffset)

definitionAt :: Text -> Analysis -> Int -> Json
definitionAt uri value offset =
  case analysisResolution value >>= (\resolution -> symbolAt resolution offset) >>= symbolSpan of
    Nothing -> JsonNull
    Just definition ->
      JsonObject
        [ ("uri", JsonText uri)
        , ( "range"
          , rangeJson
              (rangeOfOffsets (analysisText value)
                (unOffset (spanStart definition)) (unOffset (spanEnd definition)))
          )
        ]
