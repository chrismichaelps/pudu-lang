{-| @Program.Lsp.ImportCompletion — what an import may name -}
module Pudu.Lsp.ImportCompletion
  ( exportCandidates
  , importCompletions
  , importQualifiers
  , moduleMembers
  ) where

import Control.Applicative ((<|>))
import Data.Char (isAlphaNum)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Lsp.Context (ImportSite (..), declaredModule)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (completionItem, rangeOfOffsets)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Lsp.Receiver (MemberSite (..))
import Pudu.Lsp.Shapes (SumShape (..))
import Pudu.Semantic.Interface (ExportedName (..), exportsOf)
import Pudu.Semantic.Symbol (Namespace (..))

{-| Candidates at an import site of `written`; a selection is answered from
    `known`, an analysis whose program reached the selected module.

    A path is offered whole — `Std.Collections`, not `Collections` — and
    replaces everything written of the path so far, so choosing one after
    `import Std.Co` leaves `import Std.Collections` rather than a doubled
    prefix. The modules are the catalog the server found on disk and the ones
    this program already reached; the document's own module is never offered,
    since a module cannot import itself. -}
importCompletions :: [Text] -> Analysis -> Analysis -> Int -> ImportSite -> [Json]
importCompletions catalog written known offset site = case site of
  ImportPath start ->
    [ moduleItem name (rangeJson (rangeOfOffsets (analysisText written) start offset))
    | name <- Set.toAscList (Set.delete own (Set.fromList (catalog <> reached)))
    ]
  ImportSelection path -> case NonEmpty.nonEmpty (Text.splitOn "." path) of
    Just segments -> exportCandidates known (ModuleName segments)
    Nothing -> []
  ImportAlias -> []
 where
  reached = [docModule entry | entry <- indexEntries (analysisProgramIndex written)]
  own = case analysisModule written of
    Just parsed -> moduleNameText (locatedValue (moduleName parsed))
    Nothing -> maybe "" moduleNameText (declaredModule (analysisTokens written))

{-| What an import can take from `owner`: exactly the names it exports —
    functions, constants, types, traits, a sum's variants, foreign declarations
    — and nothing private. Each is presented with the documentation of that
    declaration in that module, found by module and name together, so a name
    two modules both export is described by the one the import reaches. A
    variant is described as its type's. -}
exportCandidates :: Analysis -> ModuleName -> [Json]
exportCandidates known owner =
  [ maybe (fallback exported) completionItem (Map.lookup (exportedNamespace exported, exportedName exported) documented)
  | exported <- exportsOf (analysisExports known) owner
  ]
 where
  path = moduleNameText owner
  documented =
    Map.fromList
      [ ((namespaceOf (docKind entry), docName entry), entry)
      | entry <- reverse (indexEntries (analysisProgramIndex known))
      , docModule entry == path
      , not (isMember (docKind entry))
      ]
  fallback exported = case exportedNamespace exported of
    TypeSpace -> item (exportedName exported) 22 "type"
    ValueSpace -> case variantOwner (exportedName exported) of
      Just typeName -> item (exportedName exported) 20 (typeName <> "." <> exportedName exported)
      Nothing -> item (exportedName exported) 3 ""
  variantOwner name =
    case [ typeName
         | (key, shape) <- Map.toList (analysisSums known)
         , sumModule shape == owner
         , name `elem` map fst (sumVariants shape)
         , Just typeName <- [Text.stripPrefix (path <> ".") key]
         ] of
      typeName : _ -> Just typeName
      [] -> Nothing

namespaceOf :: DocKind -> Namespace
namespaceOf kind = case kind of
  DocType -> TypeSpace
  DocTrait -> TypeSpace
  _ -> ValueSpace

isMember :: DocKind -> Bool
isMember kind = case kind of
  DocMethod _ -> True
  DocTraitMethod _ -> True
  _ -> False

{-| The declarations of a module named before the dot, as in `Io.` after
    `import Std.Io` or `import Std.Io as Io`: its exports. A qualifier no
    import binds answers nothing, and the value's members get their turn. -}
moduleMembers :: Analysis -> Analysis -> MemberSite -> [Json]
moduleMembers written known (MemberSite _ (start, end)) =
  -- Only a receiver that is one name reaches a module: `Lib.Tools.` is a
  -- path, not a qualifier.
  let qualifier = Text.take (end - start) (Text.drop start (analysisText written))
      standalone = not (Text.null qualifier) && Text.all nameScalar qualifier
   in case [owner | standalone, (bound, owner) <- importQualifiers written known, bound == qualifier] of
        owner : _ -> exportCandidates known owner
        [] -> []
 where
  nameScalar scalar = isAlphaNum scalar || scalar == '_'

{-| The qualifier each import binds, with the module it reaches, read from the
    parsed imports: `import M` binds the last segment of `M`'s path, `import M
    as N` binds `N`, and `import M { a, b }` binds no qualifier at all — only
    the names it selects. The written text's tree is asked first; while it does
    not parse, the repaired text's, whose imports are the same. -}
importQualifiers :: Analysis -> Analysis -> [(Text, ModuleName)]
importQualifiers written known =
  [ (qualifier, locatedValue (importModule entry))
  | Located _ entry <- maybe [] moduleImports (analysisModule written <|> analysisModule known)
  , null (importItems entry)
  , let qualifier = maybe (moduleQualifier (locatedValue (importModule entry))) locatedValue (importAlias entry)
  ]

item :: Text -> Int -> Text -> Json
item label kind detail =
  JsonObject
    ( [("label", JsonText label), ("kind", JsonNumber (fromIntegral kind))]
        <> [("detail", JsonText detail) | not (Text.null detail)]
    )

moduleItem :: Text -> Json -> Json
moduleItem name range =
  JsonObject
    [ ("label", JsonText name)
    , ("kind", JsonNumber 9)
    , ("detail", JsonText "module")
    , ("filterText", JsonText name)
    , ("textEdit", JsonObject [("range", range), ("newText", JsonText name)])
    ]
