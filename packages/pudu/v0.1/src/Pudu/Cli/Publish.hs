{-| @Pudu.Cli.Publish — the commands that act on a registry as a GitHub account

    `login` runs GitHub's OAuth device flow with the client id the registry
    names at `/api/v1/config` and stores the GitHub token, or stores a token
    given with `--token` after the registry accepts it; `--private` asks for
    the `repo` scope, which private repositories need. `logout` forgets the
    token. `push` registers the project, or refreshes it, from its repository's
    default branch. `release <version>` checks the project, runs its tests,
    tags the commit `v<version>`, pushes the tag, and asks the registry to
    publish it. Each takes `--registry URL`; otherwise the registry is the one
    `Remote.registryUrlFor` names. -}
module Pudu.Cli.Publish
  ( publishCommands
  , runPublishCommand
  , formBody
  ) where

import Control.Concurrent (threadDelay)
import Control.Monad (unless, when)
import qualified Data.ByteString as ByteString
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Manifest (Manifest (..), findManifestRoot, readManifest)
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import qualified Pudu.Lsp.Json as Json
import Pudu.Package.Credentials (Credential (..), loadCredential, removeCredential, saveCredential)
import Pudu.Package.Digest (treeFiles)
import Pudu.Package.Http (Request (..), Response (..), send)
import Pudu.Package.Identity (PackageId (..), parsePackageId, renderPackageId)
import Pudu.Package.Remote (registryUrlFor)
import Pudu.Package.Version (parseVersion)
import System.Directory (doesDirectoryExist, getCurrentDirectory)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (takeExtension, (</>))
import System.IO (hFlush, hPutStrLn, stderr, stdout)
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

publishCommands :: [String]
publishCommands = ["login", "logout", "whoami", "push", "release"]

runPublishCommand :: String -> [String] -> IO ()
runPublishCommand command arguments = do
  let (options, positional) = split arguments
  here <- getCurrentDirectory
  root <- findManifestRoot here
  manifest <- maybe (pure Nothing) (fmap Just . readManifest) root
  url <- case lookup "--registry" options of
    Just given -> pure (Text.dropWhileEnd (== '/') (Text.pack given))
    Nothing -> registryUrlFor (fromMaybe emptyManifest manifest)
  case command of
    "login" -> login url (Text.pack <$> lookup "--token" options) (("--private", "") `elem` options)
    "logout" -> logout url
    "whoami" -> whoami url
    "push" -> withProject command root manifest (\_ m -> push url m)
    "release" -> case positional of
      [version] -> withProject command root manifest $ \r m -> release url r m (Text.pack version) (lookup "--notes" options)
      _ -> failWith command "name the version, such as pudu release 1.4.3"
    _ -> failWith command "unknown command"
 where
  emptyManifest = Manifest Nothing Nothing Nothing [] Nothing Nothing Nothing Nothing [] []

{-| `--name value` pairs, `--flag` with an empty value, and the rest. -}
split :: [String] -> ([(String, String)], [String])
split = go [] []
 where
  go options rest [] = (reverse options, reverse rest)
  go options rest (flag : more)
    | flag `elem` ["--registry", "--token", "--notes"] = case more of
        value : after -> go ((flag, value) : options) rest after
        [] -> go ((flag, "") : options) rest []
    | take 2 flag == "--" = go ((flag, "") : options) rest more
    | otherwise = go options (flag : rest) more

withProject :: String -> Maybe FilePath -> Maybe Manifest -> (FilePath -> Manifest -> IO ()) -> IO ()
withProject command root manifest action = case (root, manifest) of
  (Just r, Just m) -> action r m
  _ -> failWith command "there is no pudu.toml here or above; run pudu init to start a project"

authorised :: Text -> [(ByteString.ByteString, ByteString.ByteString)]
authorised token = [("Authorization", "Bearer " <> TextEncoding.encodeUtf8 token)]

jsonOf :: Response -> Maybe Json
jsonOf = Json.parse . TextEncoding.decodeUtf8With (\_ _ -> Just '?') . responseBody

errorOf :: Response -> Text
errorOf response = fromMaybe ("the registry answered " <> Text.pack (show (responseStatus response))) (jsonOf response >>= lookupField "error" >>= textOf)

field :: Text -> Response -> Text
field key response = fromMaybe "" (jsonOf response >>= lookupField key >>= textOf)

call :: String -> Request -> IO Response
call command given = do
  answered <- send given
  case answered of
    Left problem -> failWith command ("cannot reach " <> requestUrl given <> ": " <> problem)
    Right response -> pure response

get :: Text -> [(ByteString.ByteString, ByteString.ByteString)] -> Request
get url headers = Request "GET" url (("Accept", "application/json") : headers) ByteString.empty

postJson :: Text -> Json -> [(ByteString.ByteString, ByteString.ByteString)] -> Request
postJson url body headers = Request "POST" url (("Content-Type", "application/json") : ("Accept", "application/json") : headers) (TextEncoding.encodeUtf8 (Json.encode body))

{-| An `application/x-www-form-urlencoded` body. -}
formBody :: [(Text, Text)] -> ByteString.ByteString
formBody pairs = TextEncoding.encodeUtf8 (Text.intercalate "&" [escape k <> "=" <> escape v | (k, v) <- pairs])
 where
  escape = Text.concatMap one
  one c
    | c `elem` (['A' .. 'Z'] <> ['a' .. 'z'] <> ['0' .. '9'] <> "-._~") = Text.singleton c
    | otherwise = Text.concat ["%" <> hex b | b <- ByteString.unpack (TextEncoding.encodeUtf8 (Text.singleton c))]
  hex b = Text.pack [digits !! fromIntegral (b `div` 16), digits !! fromIntegral (b `mod` 16)]
  digits = "0123456789ABCDEF"

postForm :: Text -> [(Text, Text)] -> Request
postForm url pairs = Request "POST" url [("Content-Type", "application/x-www-form-urlencoded"), ("Accept", "application/json")] (formBody pairs)

{-| The GitHub account the registry sees behind a token, or why it refused. -}
accountOf :: Text -> Text -> IO (Either Text Text)
accountOf url token = do
  response <- call "login" (get (url <> "/api/v1/whoami") (authorised token))
  pure (if responseStatus response == 200 then Right (field "handle" response) else Left (errorOf response))

login :: Text -> Maybe Text -> Bool -> IO ()
login url (Just token) _ = do
  account <- accountOf url token
  handle <- either (failWith "login" . ("the registry refused the token: " <>)) pure account
  saveCredential url (Credential handle token)
  TextIO.putStrLn ("signed in as " <> handle <> " on " <> url)
login url Nothing private = do
  settings <- call "login" (get (url <> "/api/v1/config") [])
  let clientId = field "githubClientId" settings
      github = Text.dropWhileEnd (== '/') (field "githubUrl" settings)
  when (Text.null clientId) (failWith "login" (url <> " has no GitHub application configured; sign in with pudu login --token <GitHub token>"))
  begun <- call "login" (postForm (github <> "/login/device/code") [("client_id", clientId), ("scope", if private then "repo" else "")])
  unless (responseStatus begun == 200) (failWith "login" ("GitHub refused to start signing in: " <> Text.pack (show (responseStatus begun))))
  let deviceCode = field "device_code" begun
      userCode = field "user_code" begun
      page = field "verification_uri" begun
      interval = maybe 5 (max 1) (jsonOf begun >>= lookupField "interval" >>= Json.integerOf)
  TextIO.putStrLn ("open " <> page <> " and enter the code " <> userCode)
  TextIO.putStr "waiting for GitHub…"
  hFlush stdout
  let poll wait = do
        threadDelay (wait * 1000000)
        answered <- call "login" (postForm (github <> "/login/oauth/access_token") [("client_id", clientId), ("device_code", deviceCode), ("grant_type", "urn:ietf:params:oauth:grant-type:device_code")])
        case (field "access_token" answered, field "error" answered) of
          (token, _) | not (Text.null token) -> do
            TextIO.putStrLn ""
            account <- accountOf url token
            handle <- either (failWith "login" . ("the registry refused the token: " <>)) pure account
            saveCredential url (Credential handle token)
            TextIO.putStrLn ("signed in as " <> handle <> " on " <> url)
          (_, "authorization_pending") -> poll wait
          (_, "slow_down") -> poll (wait + 5)
          (_, reason) -> TextIO.putStrLn "" >> failWith "login" ("GitHub did not sign you in (" <> reason <> "); run pudu login again")
  poll interval

logout :: Text -> IO ()
logout url = do
  removed <- removeCredential url
  TextIO.putStrLn $
    if removed
      then "signed out of " <> url <> "; the token itself is revoked at https://github.com/settings/applications"
      else "not signed in to " <> url

whoami :: Text -> IO ()
whoami url = do
  token <- tokenFor "whoami" url
  response <- call "whoami" (get (url <> "/api/v1/whoami") (authorised token))
  unless (responseStatus response == 200) (failWith "whoami" (errorOf response))
  TextIO.putStrLn (field "handle" response <> " on " <> url)

tokenFor :: String -> Text -> IO Text
tokenFor command url = do
  stored <- loadCredential url
  maybe (failWith command ("not signed in to " <> url <> "; run pudu login")) (pure . credentialToken) stored

packageOf :: String -> Manifest -> IO PackageId
packageOf command manifest = case manifestName manifest >>= either (const Nothing) Just . parsePackageId of
  Just package@(Registered _ _) -> pure package
  _ -> failWith command "pudu.toml must name the package as @owner/repo, its GitHub repository, to publish it"

push :: Text -> Manifest -> IO ()
push url manifest = do
  package <- packageOf "push" manifest
  token <- tokenFor "push" url
  response <- call "push" (Request "PUT" (url <> "/api/v1/packages/" <> renderPackageId package <> "/head") (("Accept", "application/json") : authorised token) ByteString.empty)
  unless (responseStatus response == 200) (failWith "push" (errorOf response))
  let repository = field "repository" response
  TextIO.putStrLn ("registered " <> renderPackageId package <> " from " <> repository <> " — " <> url <> "/" <> renderPackageId package)

git :: FilePath -> [String] -> IO (Either Text Text)
git root arguments = do
  (code, out, err) <- readCreateProcessWithExitCode (proc "git" arguments){cwd = Just root} ""
  pure (if code == ExitSuccess then Right (Text.strip (Text.pack out)) else Left (Text.strip (Text.pack err)))

release :: Text -> FilePath -> Manifest -> Text -> Maybe FilePath -> IO ()
release url root manifest version notesFile = do
  package <- packageOf "release" manifest
  token <- tokenFor "release" url
  either (failWith "release" . (("\"" <> version <> "\" is not a release version: ") <>)) (const (pure ())) (parseVersion version)
  when (manifestVersion manifest /= Just version) $
    failWith "release" ("pudu.toml gives version " <> fromMaybe "none" (manifestVersion manifest) <> "; set it to " <> version <> " and commit it before releasing")
  changes <- git root ["status", "--porcelain"]
  case changes of
    Left problem -> failWith "release" ("the project is not a git repository: " <> problem)
    Right pending -> unless (Text.null pending) (failWith "release" "the working tree has changes not committed; commit them so the release is exactly what is on GitHub")
  notes <- maybe (pure "") (fmap Text.strip . TextIO.readFile) notesFile
  verify root manifest
  let tag = "v" <> version
  commit <- either (failWith "release") pure =<< git root ["rev-parse", "HEAD"]
  existing <- git root ["rev-parse", "--verify", "--quiet", Text.unpack tag <> "^{commit}"]
  case existing of
    Right tagged | tagged /= commit -> failWith "release" (tag <> " already names another commit, " <> Text.take 12 tagged)
    Right _ -> pure ()
    Left _ -> do
      created <- git root ["tag", "-a", Text.unpack tag, "-m", Text.unpack (if Text.null notes then renderPackageId package <> " " <> version else notes)]
      either (failWith "release" . ("cannot tag the commit: " <>)) (const (pure ())) created
  pushed <- git root ["push", "origin", Text.unpack tag]
  either (failWith "release" . (("cannot push " <> tag <> " to origin: ") <>)) (const (pure ())) pushed
  TextIO.putStrLn ("tagged " <> tag <> " at " <> Text.take 7 commit <> " and pushed it to origin")
  response <-
    call "release" $
      postJson
        (url <> "/api/v1/packages/" <> renderPackageId package <> "/releases")
        (Json.object [("version", JsonText version), ("tag", JsonText tag), ("notes", JsonText notes)])
        (authorised token)
  unless (responseStatus response == 201) (failWith "release" (errorOf response))
  TextIO.putStrLn ("released " <> renderPackageId package <> " " <> version <> " (" <> field "checksum" response <> ") — install with: pudu install " <> renderPackageId package <> "@" <> version)

{-| Run `pudu check` over the project's modules and `pudu test` over its test directory, stopping at a failure. -}
verify :: FilePath -> Manifest -> IO ()
verify root manifest = do
  self <- getExecutablePath
  files <- either (const []) id <$> treeFiles root
  let source = fromMaybe "src" (manifestSource manifest)
      modules = [root </> f | f <- files, takeExtension f == ".pudu", take (length source + 1) f == source <> "/"]
  unless (null modules) $ do
    (code, out, err) <- readCreateProcessWithExitCode (proc self ("check" : modules)) ""
    when (code /= ExitSuccess) (putStr out >> hPutStrLn stderr err >> failWith "release" "the project does not check; nothing was released")
    TextIO.putStrLn ("checked " <> Text.pack (show (length modules)) <> " modules")
  tests <- filterDirectories [root </> "test", root </> "tests"]
  unless (null tests) $ do
    (code, out, err) <- readCreateProcessWithExitCode (proc self ("test" : tests)) ""
    when (code /= ExitSuccess) (putStr out >> hPutStrLn stderr err >> failWith "release" "the tests failed; nothing was released")
    TextIO.putStrLn (Text.strip (last' (Text.lines (Text.pack out))))
 where
  filterDirectories paths = fmap concat (mapM (\p -> (\e -> [p | e]) <$> doesDirectoryExist p) paths)
  last' = foldl (\_ x -> x) ""

failWith :: String -> Text -> IO a
failWith command message = do
  hPutStrLn stderr ("pudu " <> command <> ": " <> Text.unpack message)
  exitFailure
