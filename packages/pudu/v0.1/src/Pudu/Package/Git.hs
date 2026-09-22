{-| @Package.Git — a repository, fetched once and checked out by commit

    A git dependency is locked to a commit. The repository is kept as a bare
    clone in the machine's cache, named by a digest of its URL, and each commit
    a project uses is checked out once into its own directory beside it, so a
    second project on the same commit copies files and runs nothing.

    `git` is run as a program with prompts disabled: a repository that needs a
    password fails with the reason rather than waiting on a terminal nobody is
    watching. -}
module Pudu.Package.Git
  ( GitCheckout (..)
  , checkoutGit
  , cacheRoot
  ) where

import Control.Exception (IOException, try)
import qualified Data.ByteString.Char8 as Char8
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Package.Digest (sha256Hex)
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

{-| `$PUDU_HOME`, or `~/.pudu`: where downloads are kept for every project. -}
cacheRoot :: IO FilePath
cacheRoot = do
  configured <- lookupEnv "PUDU_HOME"
  base <- maybe ((</> ".pudu") <$> getHomeDirectory) pure configured
  pure (base </> "cache")

{-| The files of a repository at a revision, and the commit it named.

    With `offline`, only what the cache already holds is used: a revision it
    does not know is an error saying so. A revision already locked to a commit
    is asked for by that commit, so a moved tag changes nothing. -}
checkoutGit :: Bool -> Text -> Text -> IO (Either Text GitCheckout)
checkoutGit offline url revision = do
  cache <- cacheRoot
  let key = Text.unpack (Text.take 24 (sha256Hex (Char8.pack (Text.unpack url))))
      bare = cache </> "git" </> key
  present <- doesDirectoryExist bare
  prepared <-
    if present
      then
        if offline
          then pure (Right ())
          else discard <$> git Nothing ["--git-dir", bare, "fetch", "--quiet", "--tags", "--force", "origin", "+refs/heads/*:refs/heads/*"]
      else
        if offline
          then pure (Left (url <> " is not in the cache and --offline was given"))
          else do
            createDirectoryIfMissing True (cache </> "git")
            discard <$> git Nothing ["clone", "--bare", "--quiet", Text.unpack url, bare]
  case prepared of
    Left problem
      | offline -> pure (Left problem)
      | otherwise -> pure (Left ("cannot fetch " <> url <> ": " <> problem))
    Right () -> do
      resolved <- git Nothing ["--git-dir", bare, "rev-parse", "--verify", "--quiet", Text.unpack revision <> "^{commit}"]
      case resolved of
        Left _ ->
          pure
            ( Left
                ( url <> " has no revision " <> quoted revision
                    <> (if offline then " in the cache (--offline was given)" else "")
                )
            )
        Right output -> do
          let commit = Text.strip output
              checkout = cache </> "checkouts" </> key </> Text.unpack commit
          done <- doesDirectoryExist checkout
          if done
            then pure (Right (GitCheckout commit checkout))
            else do
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
                  pure (Right (GitCheckout commit checkout))
 where
  discard = fmap (const ())

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
