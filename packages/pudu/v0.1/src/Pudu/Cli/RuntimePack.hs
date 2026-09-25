{-| @Cli.RuntimePack — the runtime a program is attached to for another host

    A program deployed to a Linux server or a serverless function runs on a
    runtime linked against musl, so it starts wherever Linux does. Building
    one means building a toolchain, which takes hours on a machine that does
    not already have it. Each release publishes the runtime its CI built, and
    this module fetches the one matching the compiler asking for it.

    Three checks stand between a download and a deployment. Every file must
    have the SHA-256 the release's manifest names; the manifest and the files
    come over HTTPS, or plain HTTP only from this machine; and the runtime must
    carry this compiler's source digest, so the checked products a build
    carries are read by a runtime that means by them what this compiler meant.
    A pack that passes is kept, by version and digest, so the network is asked
    once per compiler rather than once per build. -}
module Pudu.Cli.RuntimePack
  ( Target (..)
  , targetNamed
  , targetNames
  , packFiles
  , runtimeFileFor
  , sharedFiles
  , resolvePack
  , renderPackProblem
  , PackProblem (..)
  ) where

import qualified Codec.Compression.GZip as GZip
import Control.Exception (SomeException, evaluate, try)
import Control.Monad (forM)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import qualified Data.ByteString.Lazy as Lazy
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Package.Digest (sha256Hex)
import qualified Pudu.Package.Http as Http
import Pudu.Version (digestIn, sourceDigest, versionText)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getHomeDirectory
  , renamePath
  )
import System.Environment (lookupEnv)
import System.FilePath ((</>))

{-| A host a program can be built for from any machine. -}
data Target
  = {-| One executable for any x86_64 Linux, whatever its C library. -}
    LinuxMusl
  | {-| A function directory for a platform that starts `bootstrap` over the
        Lambda runtime interface. -}
    Lambda
  deriving stock (Eq, Show)

targetNamed :: String -> Maybe Target
targetNamed name = lookup name [("linux-musl-x86_64", LinuxMusl), ("lambda-x86_64", Lambda)]

targetNames :: [String]
targetNames = ["linux-musl-x86_64", "lambda-x86_64"]

{-| The runtime a target attaches to: the portable one, or the one whose
    loader and libraries are named at `/var/task`, where a function lives. -}
runtimeFileFor :: Target -> FilePath
runtimeFileFor target = case target of
  LinuxMusl -> "pudu-musl-x86_64"
  Lambda -> "pudu-musl-lambda-x86_64"

{-| What a function directory carries beside its program. -}
sharedFiles :: [FilePath]
sharedFiles = ["ld-musl-x86_64.so.1", "libffi.so.8", "libz.so.1", "libncursesw.so.6", "libgmp.so.10"]

{-| Every file a pack holds, in the order the manifest lists them. -}
packFiles :: [FilePath]
packFiles = ["pudu-musl-x86_64", "pudu-musl-lambda-x86_64"] <> sharedFiles

manifestName :: Text
manifestName = "pudu-runtime-linux-musl-x86_64.sha256"

data PackProblem
  = Unreachable Text
  | NotPublished Text Int
  | BadManifest Text
  | Tampered FilePath
  | Undecodable FilePath
  | OtherSources
  | Unwritable FilePath Text
  deriving stock (Eq, Show)

renderPackProblem :: PackProblem -> Text
renderPackProblem problem = case problem of
  Unreachable reason -> "the runtime pack could not be fetched: " <> reason
  NotPublished url status ->
    url <> " answered " <> Text.pack (show status) <> "; no runtime pack is published for pudu "
      <> versionText <> " — a compiler built from a checkout rather than a release has none, so"
      <> " attach it to a runtime from the same checkout with --runtime"
  BadManifest reason -> "the runtime pack's manifest cannot be read: " <> reason
  Tampered name ->
    Text.pack name <> " does not have the SHA-256 the pack's manifest names, so it was not used"
  Undecodable name -> Text.pack name <> " is not a gzip file"
  OtherSources ->
    "the published runtime was built from other sources than this compiler (source digest "
      <> Text.take 12 sourceDigest <> "…), so it was not used"
  Unwritable path reason -> "could not store the runtime pack at " <> Text.pack path <> ": " <> reason

{-| Where packs are kept, one directory per compiler identity. -}
cacheRoot :: IO FilePath
cacheRoot = do
  configured <- lookupEnv "PUDU_RUNTIME_CACHE"
  case configured of
    Just directory | not (null directory) -> pure directory
    _ -> do
      xdg <- lookupEnv "XDG_CACHE_HOME"
      base <- case xdg of
        Just directory | not (null directory) -> pure directory
        _ -> (</> ".cache") <$> getHomeDirectory
      pure (base </> "pudu" </> "runtimes")

{-| Where the release for this version publishes its assets. -}
releaseBase :: IO Text
releaseBase = do
  configured <- lookupEnv "PUDU_RUNTIME_URL"
  pure $ case configured of
    Just url | not (null url) -> Text.dropWhileEnd (== '/') (Text.pack url)
    _ -> "https://github.com/chrismichaelps/pudu-lang/releases/download/v" <> versionText

{-| The directory holding this compiler's verified pack, fetching it first
    when it is not already kept. -}
resolvePack :: IO (Either PackProblem FilePath)
resolvePack = do
  root <- cacheRoot
  let directory = root </> Text.unpack (versionText <> "-" <> Text.take 16 sourceDigest)
      marker = directory </> ".verified"
  kept <- doesFileExist marker
  if kept
    then pure (Right directory)
    else do
      base <- releaseBase
      fetched <- fetchPack base directory
      case fetched of
        Left problem -> pure (Left problem)
        Right () -> do
          ByteString.writeFile marker (Encoding.encodeUtf8 sourceDigest)
          pure (Right directory)

fetchPack :: Text -> FilePath -> IO (Either PackProblem ())
fetchPack base directory = do
  manifest <- fetch (base <> "/" <> manifestName)
  case manifest >>= readManifest of
    Left problem -> pure (Left problem)
    Right expected -> do
      made <- try (createDirectoryIfMissing True directory) :: IO (Either SomeException ())
      case made of
        Left reason -> pure (Left (Unwritable directory (Text.pack (show reason))))
        Right () -> do
          fetched <- firstFailure packFiles $ \name -> case lookup name expected of
            Nothing -> pure (Left (BadManifest ("it names no " <> Text.pack name)))
            Just digest -> fetchOne base directory name digest
          case fetched of
            Left problem -> pure (Left problem)
            Right () -> do
              runtime <- ByteString.readFile (directory </> runtimeFileFor LinuxMusl)
              lambda <- ByteString.readFile (directory </> runtimeFileFor Lambda)
              pure $
                if digestIn runtime == Just sourceDigest && digestIn lambda == Just sourceDigest
                  then Right ()
                  else Left OtherSources

{-| Run each step in order, stopping at the first that fails. -}
firstFailure :: [a] -> (a -> IO (Either PackProblem ())) -> IO (Either PackProblem ())
firstFailure items step = case items of
  [] -> pure (Right ())
  item : rest -> do
    done <- step item
    case done of
      Left problem -> pure (Left problem)
      Right () -> firstFailure rest step

{-| One file: fetched gzipped, decompressed, checked against the manifest,
    and moved into place only once it has passed. -}
fetchOne :: Text -> FilePath -> FilePath -> Text -> IO (Either PackProblem ())
fetchOne base directory name digest = do
  body <- fetch (base <> "/" <> Text.pack name <> ".gz")
  case body of
    Left problem -> pure (Left problem)
    Right compressed -> do
      decoded <- try (evaluate (Lazy.toStrict (GZip.decompress (Lazy.fromStrict compressed)))) :: IO (Either SomeException ByteString.ByteString)
      case decoded of
        Left _ -> pure (Left (Undecodable name))
        Right bytes
          | sha256Hex bytes /= digest -> pure (Left (Tampered name))
          | otherwise -> do
              let pending = directory </> (name <> ".pending")
              written <- try (ByteString.writeFile pending bytes >> renamePath pending (directory </> name)) :: IO (Either SomeException ())
              pure $ case written of
                Left reason -> Left (Unwritable (directory </> name) (Text.pack (show reason)))
                Right () -> Right ()

{-| `<sha256>  <name>` per line, as checksum tools write it. -}
readManifest :: ByteString.ByteString -> Either PackProblem [(FilePath, Text)]
readManifest bytes = forM (filter (not . Char8.null) (Char8.lines bytes)) $ \line ->
  case Char8.words line of
    [digest, name]
      | Char8.length digest == 64 && Char8.all (`elem` ("0123456789abcdef" :: String)) digest ->
          Right (Char8.unpack (Char8.dropWhile (== '*') name), Encoding.decodeUtf8Lenient digest)
    _ -> Left (BadManifest ("a line reads " <> Encoding.decodeUtf8Lenient line))

{-| A body, following up to five redirects, since a release asset is served
    from a different host than the one that names it. Each hop is held to the
    same rule as the first: HTTPS, or plain HTTP only on this machine. -}
fetch :: Text -> IO (Either PackProblem ByteString.ByteString)
fetch = go (5 :: Int)
 where
  go hops url = do
    answered <- Http.send (Http.request "GET" url)
    case answered of
      Left reason -> pure (Left (Unreachable reason))
      Right response
        | Http.responseStatus response `elem` [301, 302, 303, 307, 308] -> case Http.header "location" response of
            Just location | hops > 0 -> go (hops - 1) (absolute url (Encoding.decodeUtf8Lenient location))
            _ -> pure (Left (Unreachable (url <> " redirected nowhere, or too many times")))
        | Http.responseStatus response /= 200 -> pure (Left (NotPublished url (Http.responseStatus response)))
        | otherwise -> pure (Right (Http.responseBody response))
  absolute from location
    | "http://" `Text.isPrefixOf` location || "https://" `Text.isPrefixOf` location = location
    | otherwise =
        let (scheme, rest) = Text.breakOn "://" from
            host = Text.takeWhile (/= '/') (Text.drop 3 rest)
         in scheme <> "://" <> host <> (if "/" `Text.isPrefixOf` location then location else "/" <> location)
