{-| @Pudu.Cli.Publish — the commands that publish through GitHub

    A package is a GitHub repository with the topic `pudu-package`; there is no
    other registry. `login` stores a GitHub token: from `--token`, from GitHub's
    OAuth device flow when `PUDU_GITHUB_CLIENT_ID` names an application, or from
    the GitHub CLI (`gh auth token`). `--private` asks the device flow for the
    `repo` scope. `logout` forgets it; `whoami` names its account.

    `release <version>` requires the manifest's version and a clean working
    tree, names every module it would ship outside the package's root, checks
    the project, runs its tests, creates the annotated tag
    `v<version>`, and pushes it to `origin`. With a token it then creates the
    GitHub release with the notes, attaches the package's API reference as
    `pudu-api.json`, and adds the `pudu-package` topic, which is what makes the
    package findable. `search <words>` lists packages from
    GitHub search. The API is `PUDU_GITHUB_API`, or `https://api.github.com`. -}
module Pudu.Cli.Publish
  ( publishCommands
  , runPublishCommand
  , formBody
  , githubApi
  , packageTopic
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, try)
import Control.Monad (unless, when)
import qualified Data.ByteString as ByteString
import Data.List (isPrefixOf, stripPrefix)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.IO as TextIO
import Pudu.Cli.ReleaseCatalogue (catalogueAsset, releaseCatalogue)
import Pudu.Compiler.Manifest (Manifest (..), findManifestRoot, readManifest)
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import qualified Pudu.Lsp.Json as Json
import Pudu.Package.Credentials (Credential (..), loadCredential, removeCredential, saveCredential)
import Pudu.Package.Digest (treeFiles)
import Pudu.Package.GitHubIndex (githubBase)
import Pudu.Package.Http (Request (..), Response (..), send)
import Pudu.Package.Identity (PackageId (..), defaultRoot, parsePackageId, renderPackageId)
import Pudu.Package.Version (parseVersion)
import System.Directory (doesDirectoryExist, getCurrentDirectory)
import System.Environment (getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (takeExtension, (</>))
import System.IO (hFlush, hPutStrLn, stderr, stdout)
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

publishCommands :: [String]
publishCommands = ["login", "logout", "whoami", "release", "search"]

{-| The topic that marks a repository as a Pudu package. -}
packageTopic :: Text
packageTopic = "pudu-package"

{-| `PUDU_GITHUB_API`, or `https://api.github.com`. -}
githubApi :: IO Text
githubApi = do
  configured <- lookupEnv "PUDU_GITHUB_API"
  pure (Text.dropWhileEnd (== '/') (maybe "https://api.github.com" Text.pack (configured >>= \v -> if null v then Nothing else Just v)))

runPublishCommand :: String -> [String] -> IO ()
runPublishCommand command arguments = do
  let (options, positional) = split arguments
  here <- getCurrentDirectory
  root <- findManifestRoot here
  manifest <- maybe (pure Nothing) (fmap Just . readManifest) root
  base <- githubBase
  api <- githubApi
  case command of
    "login" -> login base api (Text.pack <$> lookup "--token" options) (("--private", "") `elem` options)
    "logout" -> logout base
    "whoami" -> whoami base api
    "search" -> search api (Text.unwords (map Text.pack positional))
    "release" -> case (positional, root, manifest) of
      ([version], Just r, Just m) -> release base api r m (Text.pack version) (lookup "--notes" options)
      ([_], _, _) -> failWith command "there is no pudu.toml here or above; run pudu init to start a project"
      _ -> failWith command "name the version, such as pudu release 1.4.3"
    _ -> failWith command "unknown command"

{-| `--name value` pairs, `--flag` with an empty value, and the rest. -}
split :: [String] -> ([(String, String)], [String])
split = go [] []
 where
  go options rest [] = (reverse options, reverse rest)
  go options rest (flag : more)
    | flag `elem` ["--token", "--notes"] = case more of
        value : after -> go ((flag, value) : options) rest after
        [] -> go ((flag, "") : options) rest []
    | take 2 flag == "--" = go ((flag, "") : options) rest more
    | otherwise = go options (flag : rest) more

headersFor :: Maybe Text -> [(ByteString.ByteString, ByteString.ByteString)]
headersFor token =
  [("Accept", "application/vnd.github+json"), ("X-GitHub-Api-Version", "2022-11-28")]
    <> [("Authorization", "Bearer " <> TextEncoding.encodeUtf8 t) | Just t <- [token]]

jsonOf :: Response -> Maybe Json
jsonOf = Json.parse . TextEncoding.decodeUtf8With (\_ _ -> Just '?') . responseBody

field :: Text -> Response -> Text
field key response = fromMaybe "" (jsonOf response >>= lookupField key >>= textOf)

messageOf :: Response -> Text
messageOf response = fromMaybe ("GitHub answered " <> Text.pack (show (responseStatus response))) (jsonOf response >>= lookupField "message" >>= textOf)

call :: String -> Request -> IO Response
call command given = do
  answered <- send given
  case answered of
    Left problem -> failWith command ("cannot reach " <> requestUrl given <> ": " <> problem)
    Right response -> pure response

apiRequest :: ByteString.ByteString -> Text -> Maybe Text -> Maybe Json -> Request
apiRequest method url token body =
  Request method url (headersFor token <> [("Content-Type", "application/json") | Just _ <- [body]]) (maybe ByteString.empty (TextEncoding.encodeUtf8 . Json.encode) body)

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

{-| The account a token belongs to, or why GitHub refused it. -}
accountOf :: Text -> Text -> IO (Either Text Text)
accountOf api token = do
  response <- call "login" (apiRequest "GET" (api <> "/user") (Just token) Nothing)
  pure (if responseStatus response == 200 then Right ("@" <> Text.toLower (field "login" response)) else Left (messageOf response))

store :: Text -> Text -> Text -> IO ()
store base api token = do
  account <- accountOf api token
  handle <- either (failWith "login" . ("GitHub refused the token: " <>)) pure account
  saveCredential base (Credential handle token)
  TextIO.putStrLn ("signed in to GitHub as " <> handle)

login :: Text -> Text -> Maybe Text -> Bool -> IO ()
login base api (Just token) _ = store base api token
login base api Nothing private = do
  clientId <- maybe "" Text.pack <$> lookupEnv "PUDU_GITHUB_CLIENT_ID"
  if not (Text.null clientId)
    then deviceFlow base api clientId private
    else do
      ran <- try (readCreateProcessWithExitCode (proc "gh" ["auth", "token"]) "") :: IO (Either IOException (ExitCode, String, String))
      case ran of
        Right (ExitSuccess, out, _) | not (Text.null (Text.strip (Text.pack out))) -> store base api (Text.strip (Text.pack out))
        _ -> failWith "login" "sign in with pudu login --token <GitHub token>, or sign in to the GitHub CLI (gh auth login) and run pudu login again"

deviceFlow :: Text -> Text -> Text -> Bool -> IO ()
deviceFlow base api clientId private = do
  begun <- call "login" (postForm (base <> "/login/device/code") [("client_id", clientId), ("scope", if private then "repo" else "public_repo")])
  unless (responseStatus begun == 200) (failWith "login" ("GitHub refused to start signing in: " <> messageOf begun))
  let deviceCode = field "device_code" begun
      interval = maybe 5 (max 1) (jsonOf begun >>= lookupField "interval" >>= Json.integerOf)
  TextIO.putStrLn ("open " <> field "verification_uri" begun <> " and enter the code " <> field "user_code" begun)
  TextIO.putStr "waiting for GitHub…"
  hFlush stdout
  let poll wait = do
        threadDelay (wait * 1000000)
        answered <- call "login" (postForm (base <> "/login/oauth/access_token") [("client_id", clientId), ("device_code", deviceCode), ("grant_type", "urn:ietf:params:oauth:grant-type:device_code")])
        case (field "access_token" answered, field "error" answered) of
          (token, _) | not (Text.null token) -> TextIO.putStrLn "" >> store base api token
          (_, "authorization_pending") -> poll wait
          (_, "slow_down") -> poll (wait + 5)
          (_, reason) -> TextIO.putStrLn "" >> failWith "login" ("GitHub did not sign you in (" <> reason <> "); run pudu login again")
  poll interval

logout :: Text -> IO ()
logout base = do
  removed <- removeCredential base
  TextIO.putStrLn $
    if removed
      then "signed out; the token itself is revoked at https://github.com/settings/applications"
      else "not signed in"

whoami :: Text -> Text -> IO ()
whoami base api = do
  stored <- loadCredential base
  credential <- maybe (failWith "whoami" "not signed in; run pudu login") pure stored
  account <- accountOf api (credentialToken credential)
  either (failWith "whoami") TextIO.putStrLn account

search :: Text -> Text -> IO ()
search api words' = do
  let query = Text.intercalate "+" (("topic:" <> packageTopic) : filter (not . Text.null) (Text.words words'))
  response <- call "search" (apiRequest "GET" (api <> "/search/repositories?q=" <> query <> "&sort=stars&per_page=30") Nothing Nothing)
  unless (responseStatus response == 200) (failWith "search" (messageOf response))
  case jsonOf response >>= lookupField "items" of
    Just (JsonArray []) -> TextIO.putStrLn "no package matches"
    Just (JsonArray items) -> mapM_ (TextIO.putStrLn . describe) items
    _ -> failWith "search" "GitHub answered a search that is not a list of repositories"
 where
  describe item =
    let name = fromMaybe "" (lookupField "full_name" item >>= textOf)
        description = fromMaybe "" (lookupField "description" item >>= textOf)
        stars = maybe "0" (Text.pack . show) (lookupField "stargazers_count" item >>= Json.integerOf)
     in "@" <> Text.toLower name <> "  ★ " <> stars <> (if Text.null description then "" else "  " <> description)

packageOf :: Manifest -> IO PackageId
packageOf manifest = case manifestName manifest >>= either (const Nothing) Just . parsePackageId of
  Just package@(Registered _ _) -> pure package
  _ -> failWith "release" "pudu.toml must name the package @owner/repo, after its GitHub repository"

git :: FilePath -> [String] -> IO (Either Text Text)
git root arguments = do
  (code, out, err) <- readCreateProcessWithExitCode (proc "git" arguments){cwd = Just root} ""
  pure (if code == ExitSuccess then Right (Text.strip (Text.pack out)) else Left (Text.strip (Text.pack err)))

release :: Text -> Text -> FilePath -> Manifest -> Text -> Maybe FilePath -> IO ()
release base api root manifest version notesFile = do
  package <- packageOf manifest
  either (failWith "release" . (("\"" <> version <> "\" is not a release version: ") <>)) (const (pure ())) (parseVersion version)
  when (manifestVersion manifest /= Just version) $
    failWith "release" ("pudu.toml gives version " <> fromMaybe "none" (manifestVersion manifest) <> "; set it to " <> version <> " and commit it before releasing")
  changes <- git root ["status", "--porcelain"]
  case changes of
    Left problem -> failWith "release" ("the project is not a git repository: " <> problem)
    Right pending -> unless (Text.null pending) (failWith "release" "the working tree has changes not committed; commit them so the release is exactly what is on GitHub")
  notes <- maybe (pure "") (fmap Text.strip . TextIO.readFile) notesFile
  warnOutsideRoot root manifest package
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
  stored <- loadCredential base
  case (stored, package) of
    (Just credential, Registered owner name) -> announce api (credentialToken credential) root owner name tag version notes
    _ -> TextIO.putStrLn ("sign in with pudu login so releases also add the " <> packageTopic <> " topic that lists the package")
  TextIO.putStrLn ("released " <> renderPackageId package <> " " <> version <> " — install with: pudu install " <> renderPackageId package <> "@" <> version)

{-| Create the GitHub release for a tag, attach its API reference, and make
    sure the repository carries the package topic. Each step failing is
    reported, not fatal: the tag is already the release. -}
announce :: Text -> Text -> FilePath -> Text -> Text -> Text -> Text -> Text -> IO ()
announce api token root owner name tag version notes = do
  let repository = api <> "/repos/" <> owner <> "/" <> name
  created <- send (apiRequest "POST" (repository <> "/releases") (Just token) (Just (Json.object [("tag_name", JsonText tag), ("name", JsonText version), ("body", JsonText notes)])))
  uploadTo <- case created of
    Right response | responseStatus response `elem` [200, 201] -> do
      TextIO.putStrLn ("created the GitHub release " <> tag)
      pure (field "upload_url" response)
    -- The release exists already, as it does when a release is run again.
    Right response | responseStatus response == 422 -> do
      existing <- send (apiRequest "GET" (repository <> "/releases/tags/" <> tag) (Just token) Nothing)
      pure (either (const "") (field "upload_url") existing)
    Right response -> do
      hPutStrLn stderr ("pudu release: the GitHub release was not created: " <> Text.unpack (messageOf response))
      pure ""
    Left problem -> do
      hPutStrLn stderr ("pudu release: the GitHub release was not created: " <> Text.unpack problem)
      pure ""
  unless (Text.null uploadTo) (attachCatalogue token root uploadTo)
  current <- send (apiRequest "GET" (repository <> "/topics") (Just token) Nothing)
  let topics = case current of
        Right response | responseStatus response == 200 -> case jsonOf response >>= lookupField "names" of
          Just (JsonArray names) -> [t | JsonText t <- names]
          _ -> []
        _ -> []
  unless (packageTopic `elem` topics) $ do
    replaced <- send (apiRequest "PUT" (repository <> "/topics") (Just token) (Just (Json.object [("names", JsonArray (map JsonText (topics <> [packageTopic])))])))
    case replaced of
      Right response | responseStatus response == 200 -> TextIO.putStrLn ("added the " <> packageTopic <> " topic, which lists the package")
      _ -> hPutStrLn stderr ("pudu release: add the topic " <> Text.unpack packageTopic <> " to the repository on GitHub so the package is listed")

{-| Attach the release's API reference, which the website shows on the
    package's Docs tab. GitHub names an upload address with a URI template
    (`.../assets{?name,label}`); the template part is replaced by the name. An
    asset already attached under the name is left as it is. -}
attachCatalogue :: Text -> FilePath -> Text -> IO ()
attachCatalogue token root template = do
  self <- getExecutablePath
  built <- releaseCatalogue self root
  case built of
    Left problem -> hPutStrLn stderr ("pudu release: the API reference was not attached: " <> Text.unpack problem)
    Right body -> do
      let target = Text.takeWhile (/= '{') template <> "?name=" <> catalogueAsset
      sent <- send (Request "POST" target (headersFor (Just token) <> [("Content-Type", "application/json")]) body)
      case sent of
        Right response | responseStatus response `elem` [200, 201] -> TextIO.putStrLn ("attached " <> catalogueAsset <> ", the API reference the package's page shows")
        Right response | responseStatus response == 422 -> TextIO.putStrLn (catalogueAsset <> " is already attached to the release")
        Right response -> hPutStrLn stderr ("pudu release: the API reference was not attached: " <> Text.unpack (messageOf response))
        Left problem -> hPutStrLn stderr ("pudu release: the API reference was not attached: " <> Text.unpack problem)

{-| Name on stderr each module the release would ship outside the package's root.

    Such a module is allowed, but a program that installs the package and has a
    module of the same name shadows it, so the publisher hears about it before
    the tag exists. -}
warnOutsideRoot :: FilePath -> Manifest -> PackageId -> IO ()
warnOutsideRoot root manifest package = do
  files <- either (const []) id <$> treeFiles root
  let moduleRoot = fromMaybe (defaultRoot package) (manifestRoot manifest)
      source = fromMaybe "src" (manifestSource manifest)
      outside = outsideRoot moduleRoot source files
  unless (null outside) $
    hPutStrLn stderr . Text.unpack $
      "pudu release: warning: modules outside the package root "
        <> moduleRoot
        <> ": "
        <> Text.intercalate ", " (map Text.pack outside)
        <> "; a program with a module of the same name cannot use them. Move them under "
        <> Text.pack source
        <> "/"
        <> moduleRoot
        <> "/."

{-| The module files under `source` that are neither the root module, under the
    root's directory, nor the executable entry `Main.pudu`, which no program
    imports. -}
outsideRoot :: Text -> FilePath -> [FilePath] -> [FilePath]
outsideRoot moduleRoot source files =
  [file | file <- files, takeExtension file == ".pudu", Just inSource <- [stripPrefix (source <> "/") file], not (owned inSource)]
 where
  rootName = Text.unpack moduleRoot
  owned inSource = inSource == rootName <> ".pudu" || inSource == "Main.pudu" || (rootName <> "/") `isPrefixOf` inSource

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
