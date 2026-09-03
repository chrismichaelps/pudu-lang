{-| @Program.Lsp.Definition — locates the declaration named at a cursor -}
module Pudu.Lsp.Definition (definitionAt) where

import Data.Text (Text)
import Pudu.Doc (DocEntry (..), DocIndex (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (locationOf, wordAt)
import Pudu.Lsp.Json (Json (..))

definitionAt :: Text -> Analysis -> Int -> Json
definitionAt uri value offset =
  case wordAt (analysisText value) offset >>= declarationNamed (analysisIndex value) of
    Nothing -> JsonNull
    Just entry -> locationOf uri (analysisText value) entry

declarationNamed :: DocIndex -> Text -> Maybe DocEntry
declarationNamed index name =
  case [entry | entry <- indexEntries index, docName entry == name] of
    entry : _ -> Just entry
    [] -> Nothing
