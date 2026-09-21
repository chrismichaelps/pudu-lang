{-| @Program.Lsp.ImportCompletion — what an import may name -}
module Pudu.Lsp.ImportCompletion
  ( importCompletions
  ) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree (Module (..))
import Pudu.Frontend.Token (Keyword (..), SymbolKind (..), Token (..), TokenKind (..))
import Pudu.Lsp.Context (ImportSite (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (rangeOfOffsets)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)

{-| Candidates at an import site.

    A path is offered whole — `Std.Collections`, not `Collections` — and
    replaces everything written of the path so far, so choosing one after
    `import Std.Co` leaves `import Std.Collections` rather than a doubled
    prefix. The modules are the catalog the server found on disk and the ones
    this program already reached; the document's own module is never offered,
    since a module cannot import itself. -}
importCompletions :: [Text] -> Analysis -> Int -> ImportSite -> [Json]
importCompletions catalog known offset site = case site of
  ImportPath start ->
    [ moduleItem name (rangeJson (rangeOfOffsets (analysisText known) start offset))
    | name <- Set.toAscList (Set.delete own (Set.fromList (catalog <> reached)))
    ]
  ImportSelection _ -> []
  ImportAlias -> []
 where
  reached = [docModule entry | entry <- indexEntries (analysisProgramIndex known)]
  own = case analysisModule known of
    Just parsed -> moduleNameText (locatedValue (moduleName parsed))
    Nothing -> declaredModule (analysisTokens known)

{-| The module a document declares, read from its header's tokens, for a
    document that does not parse. -}
declaredModule :: [Token] -> Text
declaredModule tokens = case dropWhile ((/= Keyword KwModule) . tokenKind) tokens of
  _ : rest -> Text.concat (map spelling (takeWhile (pathKind . tokenKind) rest))
  [] -> ""
 where
  pathKind kind = case kind of
    Identifier _ -> True
    Symbol SymDot -> True
    _ -> False
  spelling token = case tokenKind token of
    Identifier name -> name
    _ -> "."

moduleItem :: Text -> Json -> Json
moduleItem name range =
  JsonObject
    [ ("label", JsonText name)
    , ("kind", JsonNumber 9)
    , ("detail", JsonText "module")
    , ("filterText", JsonText name)
    , ("textEdit", JsonObject [("range", range), ("newText", JsonText name)])
    ]
