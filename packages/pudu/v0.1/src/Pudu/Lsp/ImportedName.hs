{-| @Program.Lsp.ImportedName — the declaration another module exports, named at a cursor -}
module Pudu.Lsp.ImportedName
  ( importedEntry
  , importedNameAt
  ) where

import Data.Char (isAlphaNum)
import Data.Maybe (listToMaybe)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (symbolAt, wordSpanAt)
import Pudu.Lsp.ImportCompletion (importQualifiers)
import Pudu.Semantic.Interface (ExportedName (..), exportsOf)
import Pudu.Semantic.Symbol (Namespace (..), Symbol (..), SymbolOrigin (..))

{-| The exported declaration the name at `offset` reaches through an import:
    `Io.writeLine` after `import Std.Io`, or `writeLine` after
    `import Std.Io { writeLine }`, including the name as the import selects
    it. A qualifier no import binds, or a bare name something nearer — a local,
    a parameter, a declaration of this module — shadows, answers nothing. A
    value is preferred to a type of the same name only when the name is not
    capitalised, as a use of a variant and of its type are written alike. -}
importedNameAt :: Analysis -> Int -> Maybe ExportedName
importedNameAt value offset = do
  (word, (start, _)) <- wordSpanAt content offset
  parsed <- analysisModule value
  listToMaybe $ case qualifierBefore start of
    Just qualifier ->
      [ exported
      | (bound, owner) <- importQualifiers value value
      , bound == qualifier
      , exported <- named word owner
      ]
    Nothing
      | shadowed -> []
      | otherwise ->
          [ exported
          | Located _ entry <- moduleImports parsed
          , word `elem` map locatedValue (importItems entry)
          , exported <- named word (locatedValue (importModule entry))
          ]
 where
  content = analysisText value
  named word owner =
    let candidates = [exported | exported <- exportsOf (analysisExports value) owner, exportedName exported == word]
        valuesFirst = [e | e <- candidates, exportedNamespace e == ValueSpace] <> [e | e <- candidates, exportedNamespace e == TypeSpace]
     in if capitalised word then candidates else valuesFirst
  capitalised word = maybe False ((`elem` ['A' .. 'Z']) . fst) (Text.uncons word)
  -- The name directly before a dot ending at `start`, itself not reached
  -- through another dot: `Io` in `Io.writeLine`, nothing in `a.Io.b`.
  qualifierBefore start = case Text.unsnoc (Text.take start content) of
    Just (rest, '.') ->
      let qualifier = Text.takeWhileEnd nameScalar rest
          beforeQualifier = Text.dropEnd (Text.length qualifier) rest
       in if Text.null qualifier || Text.isSuffixOf "." beforeQualifier then Nothing else Just qualifier
    _ -> Nothing
  shadowed = case analysisResolution value >>= (`symbolAt` offset) of
    Just symbol -> symbolOrigin symbol /= ImportOrigin
    Nothing -> False
  nameScalar scalar = isAlphaNum scalar || scalar == '_'

{-| The documentation the program's index holds for an exported declaration:
    its signature and comment as its own module wrote them. -}
importedEntry :: Analysis -> ExportedName -> Maybe DocEntry
importedEntry value exported =
  listToMaybe
    [ entry
    | entry <- indexEntries (analysisProgramIndex value)
    , docModule entry == moduleNameText (exportedModule exported)
    , docName entry == exportedName exported
    , not (isMember (docKind entry))
    ]
 where
  isMember kind = case kind of
    DocMethod _ -> True
    DocTraitMethod _ -> True
    _ -> False
