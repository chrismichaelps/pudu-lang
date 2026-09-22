{-| @Package.Git — a repository, fetched once and checked out by commit

    A git dependency is locked to a commit. The repository is kept as a bare
    clone in the machine's cache, named by a digest of its URL, and each commit
    a project uses is checked out once into its own directory beside it, so a
    second project on the same commit copies files and runs nothing.

    A full commit whose checkout exists in the cache is returned without
    running git. A `GitSession` records the repositories fetched during one
    install, so each is fetched at most once, and serialises work on each
    repository with a per-URL lock. A new checkout's tree digest is written
    beside it with `cachedTreeDigest`.

    `git` is run as a program with prompts disabled: a repository that needs a
    password fails with the reason rather than waiting on a terminal nobody is
    watching. -}
module Pudu.Package.Git
  ( GitCheckout (..)
  , GitSession
  , newGitSession
  , checkoutGit
  , cacheRoot
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, newMVar, withMVar)
import Control.Exception (IOException, try)
import qualified Data.ByteString.Char8 as Char8
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Package.Digest (cachedTreeDigest, sha256Hex)
import Pudu.Package.Progress (Event (..), Progress, emit)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , getHomeDirectory
  , removeDirectoryRecursive
  , renameDirectory
  )
import System.Environment (getEnvironment, lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

data GitCheckout = GitCheckout
  { checkoutCommit :: !Text
  , checkoutDirectory :: !FilePath
  }
  deriving stock (Eq, Show)

{-| Per-install git state: the offline flag, the progress sink, one lock per
    repository URL, and the set of URLs already fetched. -}
data GitSession = GitSession
  { sessionOffline :: !Bool
  , sessionProgress :: !Progress
  , sessionLocks :: !(MVar (Map.Map Text (MVar ())))
  , sessionFetched :: !(IORef (Set.Set Text))
  }

newGitSession :: Bool -> Progress -> IO GitSession
newGitSession offline progress = GitSession offline progress <$> newMVar Map.empty <*> newIORef Set.empty

{-| `$PUDU_HOME`, or `~/.pudu`: where downloads are kept for every project. -}
cacheRoot :: IO FilePath
cacheRoot = do
  configured <- lookupEnv "PUDU_HOME"
  base <- maybe ((</> ".pudu") <$> getHomeDirectory) pure configured
  pure (base </> "cache")

{-| The files of a repository at a revision, and the commit it named.

    A revision the cache does not know is an error saying so when offline. A
    revision already locked to a commit is asked for by that commit, so a
    moved tag changes nothing. -}
checkoutGit :: GitSession -> Text -> Text -> IO (Either Text GitCheckout)
checkoutGit session url revision = do
  cache <- cacheRoot
  let key = Text.unpack (Text.take 24 (sha256Hex (Char8.pack (Text.unpack url))))
      bare = cache </> "git" </> key
      checkoutOf commit = cache </> "checkouts" </> key </> Text.unpack commit
      pinned = isCommit revision
  ready <- if pinned then doesDirectoryExist (checkoutOf revision) else pure False
  if ready
    then do
      emit (sessionProgress session) (CacheHit url)
      pure (Right (GitCheckout revision (checkoutOf revision)))
    else withRepository session url $ do
      prepared <- prepare cache bare pinned
      case prepared of
        Left problem -> pure (Left problem)
        Right () -> do
          resolved <- git Nothing ["--git-dir", bare, "rev-parse", "--verify", "--quiet", Text.unpack revision <> "^{commit}"]
          case resolved of
            Left _ ->
              pure
                ( Left
                    ( url <> " has no revision " <> quoted revision
                        <> (if sessionOffline session then " in the cache (--offline was given)" else "")
                    )
                )
            Right output -> writeOut bare (Text.strip output) checkoutOf
 where
  offline = sessionOffline session
  progress = sessionProgress session
  prepare cache bare pinned = do
    present <- doesDirectoryExist bare
    fetched <- Set.member url <$> readIORef (sessionFetched session)
    known <-
      if present && pinned && not offline && not fetched
        then either (const False) (const True) <$> git Nothing ["--git-dir", bare, "cat-file", "-e", Text.unpack revision <> "^{commit}"]
        else pure False
    if present && (offline || fetched || known)
      then do
        emit progress (CacheHit url)
        pure (Right ())
      else
        if offline
          then pure (Left (url <> " is not in the cache and --offline was given"))
          else do
            emit progress (FetchStarted url)
            createDirectoryIfMissing True (cache </> "git")
            ran <-
              if present
                then git Nothing ["--git-dir", bare, "fetch", "--quiet", "--tags", "--force", "origin", "+refs/heads/*:refs/heads/*"]
                else git Nothing ["clone", "--bare", "--quiet", Text.unpack url, bare]
            emit progress (FetchFinished url)
            atomicModifyIORef' (sessionFetched session) (\set -> (Set.insert url set, ()))
            pure (either (\problem -> Left ("cannot fetch " <> url <> ": " <> problem)) (const (Right ())) ran)
  writeOut bare commit checkoutOf = do
    let checkout = checkoutOf commit
    done <- doesDirectoryExist checkout
    if done
      then pure (Right (GitCheckout commit checkout))
      else do
        emit progress (CheckoutStarted url commit)
        let staging = checkout <> ".partial"
        leftover <- doesDirectoryExist staging
        if leftover then removeDirectoryRecursive staging else pure ()
        createDirectoryIfMissing True staging
        written <-
          git Nothing
            ["--git-dir", bare, "--work-tree", staging, "checkout", "--force", "--quiet", Text.unpack commit, "--", "."]
        case written of
          Left problem -> pure (Left ("cannot check out " <> url <> " at " <> commit <> ": " <> problem))
          Right _ -> do
            renameDirectory staging checkout
            _ <- cachedTreeDigest checkout
            pure (Right (GitCheckout commit checkout))

{-| Run an action holding the session's lock for one repository. -}
withRepository :: GitSession -> Text -> IO a -> IO a
withRepository session url action = do
  lock <- modifyMVar (sessionLocks session) $ \locks -> case Map.lookup url locks of
    Just existing -> pure (locks, existing)
    Nothing -> do
      fresh <- newMVar ()
      pure (Map.insert url fresh locks, fresh)
  withMVar lock (const action)

{-| Whether a revision is a full object name: 40 lowercase hexadecimal
    digits, or 64 for SHA-256 repositories. -}
isCommit :: Text -> Bool
isCommit revision = Text.length revision `elem` [40, 64] && Text.all (`elem` ("0123456789abcdef" :: String)) revision

git :: Maybe FilePath -> [String] -> IO (Either Text Text)
git directory arguments = do
  environment <- getEnvironment
  let quiet = ("GIT_TERMINAL_PROMPT", "0") : ("GIT_ASKPASS", "echo") : filter ((`notElem` ["GIT_DIR", "GIT_WORK_TREE"]) . fst) environment
      command = (proc "git" arguments){env = Just quiet, cwd = directory}
  ran <- try (readCreateProcessWithExitCode command "") :: IO (Either IOException (ExitCode, String, String))
  pure $ case ran of
    Left problem -> Left ("git could not be run: " <> Text.pack (show problem))
    Right (ExitSuccess, out, _) -> Right (Text.pack out)
    Right (ExitFailure _, _, err) -> Left (firstLine (Text.pack err))
 where
  firstLine text = case filter (not . Text.null) (map Text.strip (Text.lines text)) of
    line : _ -> line
    [] -> "git failed"

quoted :: Text -> Text
quoted t = "\"" <> t <> "\""
