{-| @Program.Lsp.Definition — locates the declaration named at a cursor -}
module Pudu.Lsp.Definition
  ( definitionAt
  , definitionAcross
  , fileUri
  ) where

import qualified Data.ByteString as ByteString
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Numeric (showHex)
import Data.List (isSuffixOf)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (listToMaybe)
import qualified Data.Set as Set
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (rangeOfOffsets, symbolAt)
import Pudu.Lsp.ImportedName (importedNameAt)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (rangeJson)
import Pudu.Semantic.Interface (ExportedName (..))
import Pudu.Semantic.Symbol (Symbol (..))
import Pudu.Source (SourceName (..), spanEnd, spanSource, spanStart, unOffset)
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
    Nothing -> pure (definitionAt uri value offset)
  Just exported -> do
    let declared = exportedSpan exported
        path = Text.unpack (unSourceName (spanSource declared))
    found <- readText path
    absolute <- makeAbsolute path
    pure $ case found of
      Nothing -> definitionAt uri value offset
      Just content -> location (fileUri absolute) content (unOffset (spanStart declared)) (unOffset (spanEnd declared))

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

{-| The `file:` URI of an absolute path, each byte outside the unreserved set
    and `/` percent-encoded as UTF-8, the form editors send and compare. -}
fileUri :: FilePath -> Text
fileUri path = "file://" <> Text.concat (map encoded (ByteString.unpack (Encoding.encodeUtf8 (Text.pack path))))
 where
  encoded byte
    | kept (toEnum (fromIntegral byte)) = Text.singleton (toEnum (fromIntegral byte))
    | otherwise = "%" <> Text.toUpper (Text.justifyRight 2 '0' (Text.pack (showHex byte "")))
  kept scalar = isAsciiUpper scalar || isAsciiLower scalar || isDigit scalar || scalar `elem` ("-._~/" :: String)
