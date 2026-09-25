{-| @Pudu.Cli.ReleaseCatalogue — the API reference a release carries

    `pudu release` attaches this to the GitHub release as `pudu-api.json`, so
    the website can show a release's API reference as soon as it is published
    rather than after its next build. The document is the one the website's
    build writes for a package: schema 1, the compiler's language version, and
    the declarations `pudu doc` documents that `pudu api` lists as exported,
    one per module, kind, name, and signature, sorted. -}
module Pudu.Cli.ReleaseCatalogue
  ( catalogueAsset
  , catalogueSources
  , normalizeCatalogue
  , releaseCatalogue
  ) where

import Data.List (isPrefixOf, nubBy, sortOn)
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.ByteString as ByteString
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import qualified Pudu.Lsp.Json as Json
import Pudu.Package.Digest (treeFiles)
import System.Exit (ExitCode (..))
import System.FilePath (takeExtension)
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

{-| The asset's name on the release, which the website reads by. -}
catalogueAsset :: Text
catalogueAsset = "pudu-api.json"

{-| The sources the reference covers: the project's Pudu files outside `test/`
    and `tests/`. Dot paths and the top-level `deps/` are already absent from
    what the project's tree lists. -}
catalogueSources :: [FilePath] -> [FilePath]
catalogueSources files =
  [file | file <- files, takeExtension file == ".pudu", not (any (`isPrefixOf` file) ["test/", "tests/"])]

{-| The catalogue for the project at `root`, built by the given `pudu`
    executable, or why it could not be. -}
releaseCatalogue :: FilePath -> FilePath -> IO (Either Text ByteString.ByteString)
releaseCatalogue executable root = do
  listed <- treeFiles root
  case catalogueSources <$> listed of
    Left _ -> pure (Left "the project's files could not be listed")
    Right [] -> pure (Left "the project has no Pudu sources to document")
    Right sources -> do
      documented <- jsonFrom ("doc" : "--json" : sources)
      exported <- jsonFrom ("api" : "--json" : sources)
      pure $ case (documented, exported) of
        (Right document, Right public) ->
          maybe (Left "pudu doc and pudu api did not describe the sources") (Right . TextEncoding.encodeUtf8 . Json.encode) (normalizeCatalogue document public)
        (Left problem, _) -> Left problem
        (_, Left problem) -> Left problem
 where
  jsonFrom arguments = do
    (code, out, err) <- readCreateProcessWithExitCode (proc executable arguments){cwd = Just root} ""
    pure $ case (code, Json.parse (Text.pack out)) of
      (ExitSuccess, Just value) -> Right value
      _ -> Left (Text.strip (Text.pack (if null err then out else err)))

{-| The website's catalogue from `pudu doc --json` and `pudu api --json`. An
    entry `pudu api` does not export is dropped: a documented private helper is
    not part of the package's interface. `Nothing` when either document lacks
    the list it must hold. -}
normalizeCatalogue :: Json -> Json -> Maybe Json
normalizeCatalogue document public = do
  JsonArray entries <- lookupField "entries" document
  JsonArray exports <- lookupField "exports" public
  let exported = Set.fromList (mapMaybe (\entry -> (,) <$> text "module" entry <*> text "name" entry) exports)
      normalized = mapMaybe (entryOf exported) entries
      key (moduleName, kind, name, signature, _) = (moduleName, name, kind, signature)
      unique = nubBy (\left right -> key left == key right) normalized
  pure $
    Json.object
      [ ("schemaVersion", JsonNumber 1)
      , ("languageVersion", JsonText (fromMaybe "" (text "version" public)))
      , ("entries", JsonArray (map render (sortOn key unique)))
      ]
 where
  text name value = lookupField name value >>= textOf
  entryOf exported entry = do
    moduleName <- text "module" entry
    kind <- text "kind" entry
    name <- text "name" entry
    if (moduleName, name) `Set.member` exported
      then Just (moduleName, kind, name, fromMaybe "" (text "signature" entry), docOf entry)
      else Nothing
  docOf entry = case lookupField "doc" entry of
    Just (JsonArray lines') -> [line | JsonText line <- lines']
    _ -> []
  render (moduleName, kind, name, signature, doc) =
    Json.object
      [ ("module", JsonText moduleName)
      , ("kind", JsonText kind)
      , ("name", JsonText name)
      , ("signature", JsonText signature)
      , ("doc", JsonArray (map JsonText doc))
      ]
