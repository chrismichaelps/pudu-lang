{-| @Program.Lsp.WorkspaceSymbols — symbol search across open documents -}
module Pudu.Lsp.WorkspaceSymbols (workspaceSymbolsAt) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..))
import Pudu.Lsp.Documents (Analysis (..), Documents, allDocuments)
import Pudu.Lsp.Feature (locationOf, symbolKind)
import Pudu.Lsp.Json (Json (..))

workspaceSymbolsAt :: Documents -> Text -> Json
workspaceSymbolsAt docs query =
  let q = Text.toLower query
      matches =
        [ symbolInfo uri (analysisText analysis) entry
        | (uri, analysis) <- allDocuments docs
        , entry <- indexEntries (analysisFileIndex analysis)
        , Text.null q || q `Text.isInfixOf` Text.toLower (docName entry)
        ]
   in JsonArray matches

symbolInfo :: Text -> Text -> DocEntry -> Json
symbolInfo uri content entry =
  JsonObject
    [ ("name", JsonText (docName entry))
    , ("kind", JsonNumber (fromIntegral (symbolKind (docKind entry))))
    , ("location", locationOf uri content entry)
    , ("containerName", JsonText (docModule entry))
    ]
