{-| @Package.GitHubIndex — registry packages answered by their GitHub repositories

    `@owner/repo` is the repository `<base>/owner/repo`, where `base` is
    `PUDU_GITHUB_URL` or `https://github.com`. Its releases are its tags that
    read as versions (`v1.2.0` or `1.2.0`); each release's dependencies and
    module root come from the `pudu.toml` at the tag, read from the cached bare
    clone in one `git cat-file --batch`. A tag whose manifest names another
    package, or another version, is not a release.

    Online, the tags offered are the ones `git ls-remote` still lists, so a
    deleted tag is no longer chosen while its commit stays in the cache for
    locks that name it. A locked version keeps its locked commit even when its
    tag has moved. A package whose locked version is known is answered from the
    cached clone without fetching; with `offline`, only the cache is used.

    A release published within the minimum release age (by its tag's time) is
    marked recent. -}
module Pudu.Package.GitHubIndex
  ( Index (..)
  , githubBase
  , repositoryUrl
  , lockedCommit
  , githubRegistry
  , minimumAgeFor
  ) where

import qualified Data.ByteString.Char8 as Char8
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time.Clock.POSIX (getPOSIXTime)
import Pudu.Compiler.Manifest (Dependency (..), DependencySource (..), Manifest (..), parseManifest)
import Pudu.Package.Git (GitCheckout (..), GitSession, bareRepository, checkoutGit, gitIn, gitWith)
import Pudu.Package.Identity (PackageId (..), defaultRoot, renderPackageId)
import Pudu.Package.Solve (Registry (..), ReleaseInfo (..))
import Pudu.Package.Version (parseVersion, renderVersion)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data Index = Index
  { indexBase :: !Text
  , indexSession :: !GitSession
  , indexOffline :: !Bool
  , indexMinimumAgeHours :: !Int
  , indexLocked :: !(Map.Map PackageId (Text, Text))
  -- ^ Each locked package's version and commit.
  , indexRefresh :: !(PackageId -> Bool)
  }

{-| `PUDU_GITHUB_URL`, or `https://github.com`, without a trailing `/`. -}
githubBase :: IO Text
githubBase = do
  configured <- lookupEnv "PUDU_GITHUB_URL"
  pure (Text.dropWhileEnd (== '/') (maybe "https://github.com" Text.pack (configured >>= \v -> if null v then Nothing else Just v)))

{-| Hours a release must have been tagged before a new resolution chooses
    it: `PUDU_MIN_RELEASE_AGE`, else `[install] min-release-age`, else 72. -}
minimumAgeFor :: Manifest -> IO Int
minimumAgeFor manifest = do
  configured <- lookupEnv "PUDU_MIN_RELEASE_AGE"
  let written = maybe (lookup "min-release-age" (manifestInstall manifest)) (Just . Text.pack) configured
  pure (fromMaybe 72 (written >>= readMaybe . Text.unpack . Text.dropWhileEnd (== 'h') . Text.strip))

repositoryUrl :: Text -> PackageId -> Text
repositoryUrl base package = case package of
  Registered owner name -> base <> "/" <> owner <> "/" <> name
  LocalName name -> base <> "/" <> name

{-| The commit a lock source `github+<url>#<commit>` records. -}
lockedCommit :: Text -> Maybe Text
lockedCommit source = do
  rest <- Text.stripPrefix "github+" source
  let commit = Text.takeWhileEnd (/= '#') rest
  if Text.null commit || commit == rest then Nothing else Just commit

githubRegistry :: Index -> IO Registry
githubRegistry index =
  pure
    Registry
      { registryUrl = indexBase index
      , registryReleases = releasesOf index
      , registryFetch = \package _ commit -> do
          fetched <- checkoutGit (indexSession index) (repositoryUrl (indexBase index) package) commit
          pure (checkoutDirectory <$> fetched)
      }

data Tag = Tag {tagName :: !Text, tagCommit :: !Text, tagTime :: !Integer}

releasesOf :: Index -> PackageId -> IO (Either Text [ReleaseInfo])
releasesOf index package = case package of
  LocalName name -> pure (Left (name <> " is not @owner/repo, so it names no GitHub repository"))
  Registered _ _ -> do
    let url = repositoryUrl (indexBase index) package
        locked = if indexRefresh index package then Nothing else Map.lookup package (indexLocked index)
    prepared <- bareRepository (indexSession index) url (locked /= Nothing)
    case prepared of
      Left problem -> pure (Left (missing url problem))
      Right bare -> do
        listed <- gitIn bare ["for-each-ref", "refs/tags", "--format=%(refname:strip=2) %(objectname) %(*objectname) %(creatordate:unix)"]
        live <- if indexOffline index || locked /= Nothing then pure Nothing else remoteTags url
        let tags = [t | t <- either (const []) (mapMaybe tagOf . Text.lines) listed, maybe True (Set.member (tagName t)) live]
            versioned = [(v, t) | t <- tags, Right v <- [parseVersion (Text.dropWhile (== 'v') (tagName t))]]
            pinned = [(v, maybe t (\(_, c) -> t{tagCommit = c}) (matching v)) | (v, t) <- versioned]
            matching v = case locked of
              Just (version, commit) | version == renderVersion v -> Just (version, commit)
              _ -> Nothing
        manifests <- manifestsAt bare (map (tagCommit . snd) pinned)
        now <- floor <$> getPOSIXTime
        let window = toInteger (indexMinimumAgeHours index) * 3600
        pure . Right $
          [ ReleaseInfo version (tagCommit tag) dependencies root False (window > 0 && now - tagTime tag < window)
          | (version, tag) <- pinned
          , Just text <- [Map.lookup (tagCommit tag) manifests]
          , let manifest = parseManifest text
          , manifestName manifest == Just (renderPackageId package)
          , manifestVersion manifest == Just (renderVersion version)
          , let dependencies = [(dependencyName d, requirement) | d <- manifestDependencies manifest, RegistrySource requirement <- [dependencySource d]]
                root = fromMaybe (defaultRoot package) (manifestRoot manifest)
          ]
 where
  tagOf line = case Text.words line of
    [name, object, peeled, time] -> Tag name (if Text.null peeled then object else peeled) <$> readInteger time
    [name, object, time] -> Tag name object <$> readInteger time
    _ -> Nothing
  readInteger text = if Text.all (`elem` ['0' .. '9']) text && not (Text.null text) then Just (read (Text.unpack text)) else Nothing

{-| The tag names a remote lists now, or nothing when it cannot be asked. -}
remoteTags :: Text -> IO (Maybe (Set.Set Text))
remoteTags url = do
  listed <- gitWith ["ls-remote", "--tags", "--refs", Text.unpack url] ""
  pure $ case listed of
    Left _ -> Nothing
    Right out -> Just (Set.fromList [name | line <- Text.lines out, [_, ref] <- [Text.words line], Just name <- [Text.stripPrefix "refs/tags/" ref]])

{-| The `pudu.toml` at each commit that has one, read in one batch. -}
manifestsAt :: FilePath -> [Text] -> IO (Map.Map Text Text)
manifestsAt _ [] = pure Map.empty
manifestsAt bare commits = do
  let unique = Set.toList (Set.fromList commits)
      request = concatMap (\c -> Text.unpack c <> ":pudu.toml\n") unique
  answered <- gitWith ["--git-dir", bare, "cat-file", "--batch"] request
  pure (either (const Map.empty) (Map.fromList . parseBatch unique . TextEncoding.encodeUtf8) answered)
 where
  parseBatch [] _ = []
  parseBatch (commit : rest) bytes =
    let (header, afterHeader) = Char8.break (== '\n') bytes
        body = Char8.drop 1 afterHeader
     in case Char8.words header of
          [_, "blob", size] | Just (count, _) <- Char8.readInt size ->
            (commit, TextEncoding.decodeUtf8With (\_ _ -> Just '?') (Char8.take count body)) : parseBatch rest (Char8.drop (count + 1) body)
          _ -> parseBatch rest body

missing :: Text -> Text -> Text
missing url problem
  | any (`Text.isInfixOf` Text.toLower problem) ["not found", "does not exist", "could not read", "authentication", "not appear to be a git repository"] =
      url <> " is not a repository this machine can read; check the name, or sign in to git for a private one"
  | otherwise = problem
