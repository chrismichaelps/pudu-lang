{-| @Package.Remote — a package registry reached over HTTP, through the cache

    `remoteRegistry` answers the solver's `Registry` from the `/api/v1` API.

    Project documents are cached under `cache/registry/<url digest>/`. A
    package whose locked version is in its cached document is answered from
    the cache without a request; otherwise the document is fetched, and with
    `offline` only the cache is used.

    Release archives are cached as `cache/archives/sha256-<hex>.tar.gz` and
    unpacked once into `cache/releases/sha256-<hex>/`. A cached archive whose
    digest differs from the one asked for is downloaded again; a downloaded
    one that differs is refused before it is unpacked, and an unpacked `pudu.toml` whose name or version differs
    from the release is refused. -}
module Pudu.Package.Remote
  ( Remote (..)
  , defaultRegistryUrl
  , registryUrlFor
  , minimumAgeFor
  , remoteRegistry
  , apiGet
  , projectDocument
  , releasesOf
  , cacheKey
  ) where

import Control.Exception (IOException, try)
import Control.Monad (when)
import Data.IORef (modifyIORef', newIORef, readIORef)
import qualified Data.ByteString as ByteString
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.IO as TextIO
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Pudu.Compiler.Manifest (Manifest (..), parseManifest)
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import qualified Pudu.Lsp.Json as Json
import Pudu.Package.Archive (unpackArchive)
import Pudu.Package.Digest (sha256Hex)
import Pudu.Package.Git (cacheRoot)
import Pudu.Package.Http (Request (..), Response (..), send)
import Pudu.Package.Identity (PackageId (..), renderPackageId)
import Pudu.Package.Progress (Event (..), Progress, emit)
import Pudu.Package.Solve (Registry (..), ReleaseInfo (..))
import Pudu.Package.Version (parseVersion, renderVersion)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, removeDirectoryRecursive, renameDirectory, renameFile)
import System.Environment (lookupEnv)
import System.FilePath (takeDirectory, (</>))
import Text.Read (readMaybe)

data Remote = Remote
  { remoteUrl :: !Text
  , remoteToken :: !(Maybe Text)
  , remoteOffline :: !Bool
  , remoteMinimumAgeHours :: !Int
  , remoteLocked :: !(Map.Map PackageId Text)
  , remoteProgress :: !Progress
  }

defaultRegistryUrl :: Text
defaultRegistryUrl = "https://packages.pudu-lang.org"

{-| `PUDU_REGISTRY`, else the manifest's `[install] registry`, else the default, without a trailing `/`. -}
registryUrlFor :: Manifest -> IO Text
registryUrlFor manifest = do
  configured <- lookupEnv "PUDU_REGISTRY"
  let chosen = case configured of
        Just url | not (null url) -> Text.pack url
        _ -> fromMaybe defaultRegistryUrl (lookup "registry" (manifestInstall manifest))
  pure (Text.dropWhileEnd (== '/') chosen)

{-| Hours a release must have been published before a new resolution chooses
    it: `PUDU_MIN_RELEASE_AGE`, else `[install] min-release-age`, else 72. -}
minimumAgeFor :: Manifest -> IO Int
minimumAgeFor manifest = do
  configured <- lookupEnv "PUDU_MIN_RELEASE_AGE"
  let written = maybe (lookup "min-release-age" (manifestInstall manifest)) (Just . Text.pack) configured
  pure (fromMaybe 72 (written >>= readMaybe . Text.unpack . Text.dropWhileEnd (== 'h') . Text.strip))

cacheKey :: Text -> FilePath
cacheKey url = Text.unpack (Text.take 24 (sha256Hex (TextEncoding.encodeUtf8 url)))

documentPath :: Remote -> PackageId -> IO FilePath
documentPath remote package = do
  cache <- cacheRoot
  pure (cache </> "registry" </> cacheKey (remoteUrl remote) </> Text.unpack (Text.replace "/" "__" (renderPackageId package)) <> ".json")

{-| A GET of an API path with the stored token, answering the status and body. -}
apiGet :: Remote -> Text -> IO (Either Text Response)
apiGet remote path =
  send
    Request
      { requestMethod = "GET"
      , requestUrl = remoteUrl remote <> path
      , requestHeaders = [("Accept", "application/json")] <> [("Authorization", "Bearer " <> TextEncoding.encodeUtf8 t) | Just t <- [remoteToken remote]]
      , requestBody = ByteString.empty
      }

errorOf :: Response -> Text
errorOf response = case Json.parse (TextEncoding.decodeUtf8With (\_ _ -> Just '?') (responseBody response)) >>= lookupField "error" >>= textOf of
  Just reason -> reason
  Nothing -> "the registry answered " <> Text.pack (show (responseStatus response))

{-| A project's document: from the cache when it holds the locked version,
    otherwise from the registry, which refreshes the cache. -}
projectDocument :: Remote -> PackageId -> IO (Either Text Json)
projectDocument remote package = do
  path <- documentPath remote package
  cached <- readCached path
  let lockedVersion = Map.lookup package (remoteLocked remote)
      holdsLocked document = maybe False (\v -> v `elem` [renderVersion (releaseVersion r) | r <- releasesOf 0 Nothing document]) lockedVersion
  case cached of
    Just document | remoteOffline remote || holdsLocked document -> do
      emit (remoteProgress remote) (CacheHit (renderPackageId package))
      pure (Right document)
    _
      | remoteOffline remote -> pure (Left (renderPackageId package <> " is not in the cache and --offline was given"))
      | otherwise -> do
          emit (remoteProgress remote) (FetchStarted (renderPackageId package))
          answered <- apiGet remote ("/api/v1/packages/" <> renderPackageId package)
          emit (remoteProgress remote) (FetchFinished (renderPackageId package))
          case answered of
            Left problem -> pure (Left ("cannot reach " <> remoteUrl remote <> ": " <> problem))
            Right response
              | responseStatus response == 404 -> Left <$> missing remote package
              | responseStatus response /= 200 -> pure (Left (renderPackageId package <> ": " <> errorOf response))
              | otherwise -> case Json.parse (TextEncoding.decodeUtf8With (\_ _ -> Just '?') (responseBody response)) of
                  Nothing -> pure (Left (renderPackageId package <> ": the registry answered a document that is not JSON"))
                  Just document -> do
                    createDirectoryIfMissing True (takeDirectory path)
                    ByteString.writeFile (path <> ".partial") (responseBody response)
                    renameFile (path <> ".partial") path
                    pure (Right document)
 where
  readCached path = do
    present <- doesFileExist path
    if not present
      then pure Nothing
      else do
        loaded <- try (TextIO.readFile path) :: IO (Either IOException Text)
        pure (either (const Nothing) Json.parse loaded)

{-| The error for a name the registry does not know, naming close matches from a search. -}
missing :: Remote -> PackageId -> IO Text
missing remote package = do
  let base = renderPackageId package <> " is not a project on " <> remoteUrl remote
      query = case package of
        Registered _ name -> name
        LocalName name -> name
  searched <- apiGet remote ("/api/v1/packages?q=" <> query)
  let names = case searched of
        Right response | responseStatus response == 200 -> case Json.parse (TextEncoding.decodeUtf8With (\_ _ -> Just '?') (responseBody response)) >>= lookupField "projects" of
          Just (JsonArray projects) -> take 3 (mapMaybe (\p -> lookupField "name" p >>= textOf) projects)
          _ -> []
        _ -> []
  pure (if null names then base else base <> " — did you mean " <> Text.intercalate ", " names <> "?")

{-| The releases in a project document. A release published less than
    `hours` before `now` is marked recent. -}
releasesOf :: Int -> Maybe UTCTime -> Json -> [ReleaseInfo]
releasesOf hours now document = case lookupField "releases" document of
  Just (JsonArray releases) -> mapMaybe one releases
  _ -> []
 where
  root = fromMaybe "" (lookupField "root" document >>= textOf)
  one release = do
    versionText <- lookupField "version" release >>= textOf
    version <- either (const Nothing) Just (parseVersion versionText)
    checksum <- lookupField "checksum" release >>= textOf
    let dependencies = case lookupField "dependencies" release of
          Just (JsonObject fields) -> [(k, v) | (k, JsonText v) <- fields]
          _ -> []
        yanked = lookupField "yanked" release == Just (JsonBool True)
        published = lookupField "publishedAt" release >>= textOf >>= iso8601ParseM . Text.unpack
        recent = case (now, published) of
          (Just at, Just when') -> hours > 0 && diffUTCTime at when' < fromIntegral (hours * 3600)
          _ -> False
    Just (ReleaseInfo version checksum dependencies root yanked recent)

{-| A `Registry` over the remote. Each project document is read at most once per registry value. -}
remoteRegistry :: Remote -> IO Registry
remoteRegistry remote = do
  now <- getCurrentTime
  documents <- newIORef Map.empty
  let documentOf package = do
        known <- Map.lookup package <$> readIORef documents
        case known of
          Just answer -> pure answer
          Nothing -> do
            answer <- projectDocument remote package
            modifyIORef' documents (Map.insert package answer)
            pure answer
  pure
    Registry
      { registryUrl = remoteUrl remote
      , registryReleases = \package -> fmap (releasesOf (remoteMinimumAgeHours remote) (Just now)) <$> documentOf package
      , registryFetch = fetchRelease remote
      }

fetchRelease :: Remote -> PackageId -> Text -> Text -> IO (Either Text FilePath)
fetchRelease remote package version checksum = do
  cache <- cacheRoot
  let hex = fromMaybe checksum (Text.stripPrefix "sha256:" checksum)
      label = renderPackageId package <> " " <> version
      archivePath = cache </> "archives" </> ("sha256-" <> Text.unpack hex <> ".tar.gz")
      unpacked = cache </> "releases" </> ("sha256-" <> Text.unpack hex)
  done <- doesDirectoryExist unpacked
  if done
    then pure (Right unpacked)
    else do
      held <- doesFileExist archivePath
      cached <- if held then Just <$> ByteString.readFile archivePath else pure Nothing
      bytes <- case cached of
        Just archive | "sha256:" <> sha256Hex archive == checksum -> pure (Right archive)
        _
          | remoteOffline remote -> pure (Left (label <> " is not in the cache and --offline was given"))
          | otherwise -> do
              emit (remoteProgress remote) (FetchStarted label)
              answered <- apiGet remote ("/api/v1/packages/" <> renderPackageId package <> "/releases/" <> version <> "/archive")
              emit (remoteProgress remote) (FetchFinished label)
              pure $ case answered of
                Left problem -> Left ("cannot download " <> label <> ": " <> problem)
                Right response
                  | responseStatus response == 200 -> Right (responseBody response)
                  | otherwise -> Left ("cannot download " <> label <> ": " <> errorOf response)
      case bytes of
        Left problem -> pure (Left problem)
        Right archive -> do
          let actual = "sha256:" <> sha256Hex archive
          if actual /= checksum
            then
              pure
                ( Left
                    ( "the archive downloaded for " <> label <> " has digest " <> actual
                        <> ", and the registry and pudu.lock record " <> checksum <> "; nothing was installed"
                    )
                )
            else do
              createDirectoryIfMissing True (cache </> "archives")
              createDirectoryIfMissing True (cache </> "releases")
              ByteString.writeFile (archivePath <> ".partial") archive
              renameFile (archivePath <> ".partial") archivePath
              let unverified = unpacked <> ".unverified"
              leftover <- doesDirectoryExist unverified
              when leftover (removeDirectoryRecursive unverified)
              written <- unpackArchive archive unverified
              case written of
                Left problem -> pure (Left (label <> ": " <> problem))
                Right () -> do
                  confirmed <- confirm unverified label
                  case confirmed of
                    Left problem -> Left problem <$ removeDirectoryRecursive unverified
                    Right () -> Right unpacked <$ renameDirectory unverified unpacked
 where
  confirm directory label = do
    present <- doesFileExist (directory </> "pudu.toml")
    manifest <- if present then parseManifest <$> TextIO.readFile (directory </> "pudu.toml") else pure (parseManifest "")
    pure $
      if manifestName manifest /= Just (renderPackageId package) || manifestVersion manifest /= Just version
        then Left (label <> ": the pudu.toml in its archive names " <> fromMaybe "nothing" (manifestName manifest) <> " " <> fromMaybe "" (manifestVersion manifest) <> ", not the release")
        else Right ()
