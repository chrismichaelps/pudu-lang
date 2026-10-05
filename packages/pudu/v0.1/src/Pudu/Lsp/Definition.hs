{-| @Program.Lsp.Definition — locates the declaration named at a cursor -}
module Pudu.Lsp.Definition
  ( definitionAt
  , definitionAcross
  , fileUri
  ) where

import Data.Char (isAlphaNum)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.List (isSuffixOf)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (catMaybes, listToMaybe)
import qualified Data.Set as Set
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Context (contextAt, contextParameters)
import Pudu.Lsp.Feature (rangeOfOffsets, symbolAt, wordSpanAt)
import Pudu.Lsp.ImportedName (importedNameAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.MethodOwner (declaredOn, receiverOwners, traitMembersNamed, writtenOwners)
import Pudu.Lsp.Protocol (fileUri, rangeJson)
import Pudu.Lsp.Receiver (MemberSite (..), memberSiteAt, receiverType)
import Pudu.Semantic.Interface (ExportedName (..))
import Pudu.Semantic.Symbol (Symbol (..))
import Pudu.Source (SourceName (..), Span, sourceName, spanEnd, spanSource, spanStart, unOffset)
import Pudu.Type (Type (..))
import System.Directory (makeAbsolute)
import System.FilePath (joinPath, pathSeparator, (<.>))

{-| The declaration in this document the name at `offset` resolves to. -}
definitionAt :: Text -> Analysis -> Int -> Json
definitionAt uri value offset =
  case analysisResolution value >>= (\resolution -> symbolAt resolution offset) >>= symbolSpan of
    Nothing -> JsonNull
    Just definition -> location uri (analysisText value) (unOffset (spanStart definition)) (unOffset (spanEnd definition))

{-| The declaration the name at `offset` names: when it reaches another
    module's export through an import, that export in its module's file — not
    the import that brought it in, which only repeats the name — and otherwise
    `definitionAt`. `readText` gives the text of a file by its path — the
    editor's copy when the file is open — and nothing when it cannot be read,
    since offsets become positions only against the text they were taken
    from. -}
definitionAcross :: (FilePath -> IO (Maybe Text)) -> Text -> Analysis -> Int -> IO Json
definitionAcross readText uri value offset = case importedNameAt value offset of
  Nothing -> case importedModuleAt value offset of
    Just path -> do
      absolute <- makeAbsolute path
      pure (JsonObject [("uri", JsonText (fileUri absolute)), ("range", rangeJson (rangeOfOffsets "" 0 0))])
    Nothing -> case methodsAt value offset of
      [] -> pure (definitionAt uri value offset)
      spans -> do
        found <- catMaybes <$> mapM (spanLocation readText uri value) spans
        pure $ case found of
          [] -> definitionAt uri value offset
          [only] -> only
          several -> JsonArray several
  Just exported -> do
    let declared = exportedSpan exported
        path = Text.unpack (unSourceName (spanSource declared))
    found <- readText path
    absolute <- makeAbsolute path
    pure $ case found of
      Nothing -> definitionAt uri value offset
      Just content -> location (fileUri absolute) content (unOffset (spanStart declared)) (unOffset (spanEnd declared))

{-| The declarations of the method named after a dot at `offset`, looked up
    under the owners its receiver's methods are filed by: a typed value's
    type, or a written type or type parameter for a static call. A type that
    declares nothing of that name may inherit a trait's default, so the trait
    members of that name answer then. A generated method's span is its anchor
    in the derive that wrote it. -}
methodsAt :: Analysis -> Int -> [Span]
methodsAt value offset = case (memberSiteAt (analysisTokens value) offset, wordSpanAt content offset) of
  (Just site@(MemberSite dot (start, end)), Just (name, (nameStart, _)))
    | nameStart > dot ->
        let parameters = contextParameters (contextAt (analysisTokens value) (analysisModule value) offset)
            owners = case analysisTypes value >>= (`receiverType` site) of
              Just receiver -> receiverOwners value parameters receiver
              Nothing -> writtenReceiver parameters (Text.take (end - start) (Text.drop start content))
            own = [at | key <- owners, (member, _, at) <- declaredOn value key, member == name]
         in if null own then [at | (_, _, at) <- traitMembersNamed value name] else own
  _ -> []
 where
  content = analysisText value
  writtenReceiver parameters written = case Text.splitOn "." written of
    [single] | single `elem` map fst parameters -> receiverOwners value parameters (RigidType single)
    first : rest | all isName (first : rest) -> writtenOwners value (ModuleName (first :| rest))
    _ -> []
  isName segment = not (Text.null segment) && Text.all (\scalar -> isAlphaNum scalar || scalar == '_') segment

{-| A span as a location: in this document against its text, and in another
    file against that file's text, nothing when it cannot be read. -}
spanLocation :: (FilePath -> IO (Maybe Text)) -> Text -> Analysis -> Span -> IO (Maybe Json)
spanLocation readText uri value at
  | spanSource at == sourceName (analysisSource value) =
      pure (Just (location uri (analysisText value) (unOffset (spanStart at)) (unOffset (spanEnd at))))
  | otherwise = do
      let path = Text.unpack (unSourceName (spanSource at))
      found <- readText path
      absolute <- makeAbsolute path
      pure (fmap (\content -> location (fileUri absolute) content (unOffset (spanStart at)) (unOffset (spanEnd at))) found)

{-| The file of the module an import's path names, when the cursor is on the
    path: one of the files the program read, found by the path the module name
    spells beneath its source root. -}
importedModuleAt :: Analysis -> Int -> Maybe FilePath
importedModuleAt value offset = do
  parsed <- analysisModule value
  target <-
    listToMaybe
      [ locatedValue path
      | Located _ entry <- moduleImports parsed
      , let path = importModule entry
      , unOffset (spanStart (locatedSpan path)) <= offset
      , offset <= unOffset (spanEnd (locatedSpan path))
      ]
  let relative = joinPath (map Text.unpack (NonEmpty.toList (moduleNameSegments target))) <.> "pudu"
  listToMaybe [path | path <- Set.toList (analysisDependencies value), (pathSeparator : relative) `isSuffixOf` path]

location :: Text -> Text -> Int -> Int -> Json
location uri content start end =
  JsonObject [("uri", JsonText uri), ("range", rangeJson (rangeOfOffsets content start end))]
