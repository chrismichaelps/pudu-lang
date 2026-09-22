{-| @Pudu.Cli.Publish — the commands that talk to a registry as an account

    `login` pairs this machine with an account by device code, or stores a
    token given with `--token` after `whoami` accepts it. `logout` revokes the
    token and forgets it. `push` uploads the project's files as its latest
    snapshot. `release <version>` checks the project, runs its tests, and
    uploads an immutable release. Each takes `--registry URL`; otherwise the
    registry is the one `Remote.registryUrlFor` names. -}
module Pudu.Cli.Publish
  ( publishCommands
  , runPublishCommand
  , multipart
  ) where

import Control.Concurrent (threadDelay)
import Control.Monad (unless, when)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Manifest (Manifest (..), findManifestRoot, readManifest)
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import qualified Pudu.Lsp.Json as Json
import Pudu.Package.Archive (packDirectory)
import Pudu.Package.Credentials (Credential (..), loadCredential, removeCredential, saveCredential)
import Pudu.Package.Digest (sha256Hex, treeFiles)
import Pudu.Package.Http (Request (..), Response (..), send)
import Pudu.Package.Identity (PackageId (..), parsePackageId, renderPackageId)
import Pudu.Package.Remote (registryUrlFor)
import Pudu.Package.Version (parseVersion)
import System.Directory (doesDirectoryExist, getCurrentDirectory)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (takeExtension, (</>))
import System.IO (hFlush, hPutStrLn, stderr, stdout)
import System.Process (proc, readCreateProcessWithExitCode)

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
    Nothing -> registryUrlFor (fromMaybe (emptyOf manifest) manifest)
  case command of
    "login" -> login url (Text.pack <$> lookup "--token" options)
    "logout" -> logout url
    "whoami" -> whoami url
    "push" -> withProject command root manifest $ \r m -> push url r m (visibilityOf options)
    "release" -> case positional of
      [version] -> withProject command root manifest $ \r m -> release url r m (Text.pack version) (lookup "--notes" options) (visibilityOf options)
      _ -> failWith command "name the version, such as pudu release 1.4.3"
    _ -> failWith command "unknown command"
 where
  emptyOf = const (Manifest Nothing Nothing Nothing [] Nothing Nothing Nothing Nothing [] [])
  visibilityOf options = if ("--private", "") `elem` options then "private" else ""

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

get :: Text -> Text -> [(ByteString.ByteString, ByteString.ByteString)] -> Request
get url path headers = Request "GET" (url <> path) headers ByteString.empty

post :: Text -> Text -> ByteString.ByteString -> [(ByteString.ByteString, ByteString.ByteString)] -> Request
post url path body headers = Request "POST" (url <> path) (("Content-Type", "application/json") : headers) body

login :: Text -> Maybe Text -> IO ()
login url (Just token) = do
  response <- call "login" (get url "/api/v1/whoami" (authorised token))
  unless (responseStatus response == 200) (failWith "login" ("the registry refused the token: " <> errorOf response))
  saveCredential url (Credential (field "handle" response) token)
  TextIO.putStrLn ("signed in as " <> field "handle" response <> " on " <> url)
login url Nothing = do
  begun <- call "login" (post url "/api/v1/login/device" "{}" [])
  unless (responseStatus begun == 200) (failWith "login" (errorOf begun))
  let deviceCode = field "deviceCode" begun
      userCode = field "userCode" begun
      page = field "verificationUrl" begun
      interval = maybe 2 (max 1) (jsonOf begun >>= lookupField "interval" >>= Json.integerOf)
  TextIO.putStrLn ("open " <> page <> "?code=" <> userCode <> " and enter the code " <> userCode)
  TextIO.putStr "waiting for approval…"
  hFlush stdout
  let poll = do
        threadDelay (interval * 1000000)
        answered <- call "login" (post url "/api/v1/login/device/token" (TextEncoding.encodeUtf8 (Json.encode (Json.object [("deviceCode", JsonText deviceCode)]))) [])
        case responseStatus answered of
          200 -> do
            TextIO.putStrLn ""
            saveCredential url (Credential (field "handle" answered) (field "token" answered))
            TextIO.putStrLn ("signed in as " <> field "handle" answered <> " on " <> url)
          428 -> poll
          _ -> TextIO.putStrLn "" >> failWith "login" (errorOf answered <> "; run pudu login again")
  poll

logout :: Text -> IO ()
logout url = do
  stored <- loadCredential url
  case stored of
    Nothing -> TextIO.putStrLn ("not signed in to " <> url)
    Just credential -> do
      _ <- send (Request "DELETE" (url <> "/api/v1/tokens/current") (authorised (credentialToken credential)) ByteString.empty)
      removed <- removeCredential url
      TextIO.putStrLn (if removed then "signed out of " <> url else "the token comes from PUDU_TOKEN; unset it to sign out")

whoami :: Text -> IO ()
whoami url = do
  token <- tokenFor "whoami" url
  response <- call "whoami" (get url "/api/v1/whoami" (authorised token))
  unless (responseStatus response == 200) (failWith "whoami" (errorOf response))
  TextIO.putStrLn (field "handle" response <> " on " <> url)

tokenFor :: String -> Text -> IO Text
tokenFor command url = do
  stored <- loadCredential url
  maybe (failWith command ("not signed in to " <> url <> "; run pudu login")) (pure . credentialToken) stored

packageOf :: String -> Manifest -> IO PackageId
packageOf command manifest = case manifestName manifest >>= either (const Nothing) Just . parsePackageId of
  Just package@(Registered _ _) -> pure package
  _ -> failWith command "pudu.toml must name the package as @handle/name to publish it"

{-| A `multipart/form-data` body of text fields and one file, with its content type. -}
multipart :: [(Text, Text)] -> (Text, ByteString.ByteString) -> (ByteString.ByteString, ByteString.ByteString)
multipart fields (fileField, content) =
  let boundary = "pudu-" <> Char8.pack (Text.unpack (Text.take 32 (sha256Hex content)))
      part name extra payload = "--" <> boundary <> "\r\nContent-Disposition: form-data; name=\"" <> TextEncoding.encodeUtf8 name <> "\"" <> extra <> "\r\n\r\n" <> payload <> "\r\n"
      body =
        ByteString.concat [part name "" (TextEncoding.encodeUtf8 value) | (name, value) <- fields]
          <> part fileField "; filename=\"package.tar.gz\"\r\nContent-Type: application/gzip" content
          <> "--" <> boundary <> "--\r\n"
   in (body, "multipart/form-data; boundary=" <> boundary)

upload :: String -> ByteString.ByteString -> Text -> Text -> [(Text, Text)] -> ByteString.ByteString -> IO Response
upload command method url path fields archive = do
  token <- tokenFor command url
  let (body, contentType) = multipart fields ("archive", archive)
  call command (Request method (url <> path) (("Content-Type", contentType) : authorised token) body)

packProject :: String -> FilePath -> IO (ByteString.ByteString, Int)
packProject command root = do
  packed <- packDirectory root
  archive <- either (failWith command) pure packed
  files <- either (const []) id <$> treeFiles root
  pure (archive, length (filter ((== ".pudu") . takeExtension) files))

push :: Text -> FilePath -> Manifest -> Text -> IO ()
push url root manifest visibility = do
  package <- packageOf "push" manifest
  (archive, modules) <- packProject "push" root
  response <- upload "push" "PUT" url ("/api/v1/packages/" <> renderPackageId package <> "/head") [("visibility", visibility)] archive
  unless (responseStatus response == 200) (failWith "push" (errorOf response))
  TextIO.putStrLn
    ( "pushed " <> renderPackageId package <> " (" <> Text.pack (show modules) <> " modules, " <> kilobytes (ByteString.length archive)
        <> ") — " <> url <> "/" <> renderPackageId package
    )

release :: Text -> FilePath -> Manifest -> Text -> Maybe FilePath -> Text -> IO ()
release url root manifest version notesFile visibility = do
  package <- packageOf "release" manifest
  either (failWith "release" . (("\"" <> version <> "\" is not a release version: ") <>)) (const (pure ())) (parseVersion version)
  when (manifestVersion manifest /= Just version) $
    failWith "release" ("pudu.toml gives version " <> fromMaybe "none" (manifestVersion manifest) <> "; set it to " <> version <> " before releasing")
  notes <- maybe (pure "") (fmap Text.strip . TextIO.readFile) notesFile
  verify root manifest
  (archive, _) <- packProject "release" root
  response <- upload "release" "POST" url ("/api/v1/packages/" <> renderPackageId package <> "/releases") [("version", version), ("notes", notes), ("visibility", visibility)] archive
  unless (responseStatus response == 201) (failWith "release" (errorOf response))
  TextIO.putStrLn
    ( "released " <> renderPackageId package <> " " <> version <> " (" <> kilobytes (ByteString.length archive) <> ", " <> field "checksum" response
        <> ") — install with: pudu install " <> renderPackageId package <> "@" <> version
    )

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

kilobytes :: Int -> Text
kilobytes size
  | size < 1024 = Text.pack (show size) <> " B"
  | otherwise = Text.pack (show ((size + 1023) `div` 1024)) <> " KB"

failWith :: String -> Text -> IO a
failWith command message = do
  hPutStrLn stderr ("pudu " <> command <> ": " <> Text.unpack message)
  exitFailure
