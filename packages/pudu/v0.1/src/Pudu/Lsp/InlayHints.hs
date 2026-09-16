{-| @Program.Lsp.InlayHints — inferred type hints on bindings -}
module Pudu.Lsp.InlayHints (inlayHintsAt) where

import qualified Data.Text as Text
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (offsetAt, positionAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (Range (..), positionJson)
import Pudu.Semantic.Resolve (Resolution (..))
import Pudu.Semantic.Symbol (Symbol (..), SymbolOrigin (..))
import Pudu.Source (spanEnd, spanStart, unOffset)
import Pudu.Type (narrowestAt, renderType)

inlayHintsAt :: Analysis -> Range -> Json
inlayHintsAt value requestRange =
  case analysisResolution value of
    Nothing -> JsonArray []
    Just resolution ->
      let content = analysisText value
          startOff = offsetAt content (rangeStart requestRange)
          endOff = offsetAt content (rangeEnd requestRange)
          symbolsInRange =
            [ symbol
            | symbol <- resolutionSymbols resolution
            , symbolOrigin symbol == LocalOrigin || symbolOrigin symbol == PatternOrigin
            , Just defSpan <- [symbolSpan symbol]
            , let sOff = unOffset (spanStart defSpan)
            , sOff >= startOff && sOff <= endOff
            ]
          hints = [hintForSymbol value content s | s <- symbolsInRange]
       in JsonArray [h | Just h <- hints]

hintForSymbol :: Analysis -> Text.Text -> Symbol -> Maybe Json
hintForSymbol value content symbol = do
  defSpan <- symbolSpan symbol
  let endOff = unOffset (spanEnd defSpan)
      afterText = Text.stripStart (Text.take 20 (Text.drop endOff content))
  if Text.isPrefixOf ":" afterText
    then Nothing
    else do
      types <- analysisTypes value
      typeVal <- narrowestAt (unOffset (spanStart defSpan)) types
      let pos = positionAt content endOff
      pure $
        JsonObject
          [ ("position", positionJson pos)
          , ("label", JsonText (": " <> renderType typeVal))
          , ("kind", JsonNumber 1)
          , ("paddingLeft", JsonBool False)
          , ("paddingRight", JsonBool True)
          ]
