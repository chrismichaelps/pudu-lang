{-# LANGUAGE CPP #-}

{-| @Package.Credentials — registry tokens stored on this machine

    Tokens are kept per registry URL in `$PUDU_HOME/credentials.toml`
    (default `~/.pudu`). The file is written through a staging file whose
    mode is set to 0600 before the token is written, then renamed into place.
    `PUDU_TOKEN`, when set, is used for every registry instead of the file. -}
module Pudu.Package.Credentials
  ( Credential (..)
  , puduHome
  , credentialsPath
  , loadCredential
  , saveCredential
  , removeCredential
  ) where

import Control.Exception (IOException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Directory (createDirectoryIfMissing, doesFileExist, getHomeDirectory, renameFile)
import System.Environment (lookupEnv)
import System.FilePath ((</>))
#if defined(PUDU_POSIX_SIGNALS)
import System.Posix.Files (setFileMode)
#else
import System.Directory (emptyPermissions, setOwnerReadable, setOwnerWritable, setPermissions)
#endif

data Credential = Credential
  { credentialHandle :: !Text
  , credentialToken :: !Text
  }
  deriving stock (Eq, Show)

{-| `$PUDU_HOME`, or `~/.pudu`. -}
puduHome :: IO FilePath
puduHome = do
  configured <- lookupEnv "PUDU_HOME"
  maybe ((</> ".pudu") <$> getHomeDirectory) pure configured

credentialsPath :: IO FilePath
credentialsPath = (</> "credentials.toml") <$> puduHome

{-| Every stored credential, by registry URL. -}
readAll :: IO [(Text, Credential)]
readAll = do
  path <- credentialsPath
  present <- doesFileExist path
  if not present
    then pure []
    else do
      loaded <- try (TextIO.readFile path) :: IO (Either IOException Text)
      pure (either (const []) parse loaded)
 where
  parse text = collect Nothing [] (map Text.strip (Text.lines text))
  collect current acc [] = reverse (flush current acc)
  collect current acc (line : rest)
    | Just inner <- Text.stripPrefix "[registry." line >>= Text.stripSuffix "]" = collect (Just (unquote inner, "", "")) (flush current acc) rest
    | Just (url, _, token) <- current, Just value <- valueOf "handle" line = collect (Just (url, value, token)) acc rest
    | Just (url, handle, _) <- current, Just value <- valueOf "token" line = collect (Just (url, handle, value)) acc rest
    | otherwise = collect current acc rest
  flush current acc = case current of
    Just (url, handle, token) | not (Text.null token) -> (url, Credential handle token) : acc
    _ -> acc
  valueOf key line = do
    rest <- Text.stripPrefix key line
    value <- Text.stripPrefix "=" (Text.strip rest)
    Just (unquote (Text.strip value))
  unquote = Text.dropAround (== '"')

{-| The token for a registry: `PUDU_TOKEN` when set, otherwise the stored one. -}
loadCredential :: Text -> IO (Maybe Credential)
loadCredential url = do
  fromEnvironment <- lookupEnv "PUDU_TOKEN"
  case fromEnvironment of
    Just token | not (null token) -> pure (Just (Credential "" (Text.pack token)))
    _ -> lookup url <$> readAll

saveCredential :: Text -> Credential -> IO ()
saveCredential url credential = do
  existing <- readAll
  writeAll ((url, credential) : filter ((/= url) . fst) existing)

{-| Forget a registry's token; answers whether one was stored. -}
removeCredential :: Text -> IO Bool
removeCredential url = do
  existing <- readAll
  let kept = filter ((/= url) . fst) existing
  if length kept == length existing then pure False else True <$ writeAll kept

writeAll :: [(Text, Credential)] -> IO ()
writeAll entries = do
  home <- puduHome
  createDirectoryIfMissing True home
  path <- credentialsPath
  let staging = path <> ".partial"
      rendered =
        "# Written by pudu login. It holds secrets: keep it private.\n"
          <> Text.concat
            [ "\n[registry.\"" <> url <> "\"]\nhandle = \"" <> credentialHandle c <> "\"\ntoken = \"" <> credentialToken c <> "\"\n"
            | (url, c) <- entries
            ]
  TextIO.writeFile staging ""
  ownerOnly staging
  TextIO.writeFile staging rendered
  renameFile staging path

ownerOnly :: FilePath -> IO ()
#if defined(PUDU_POSIX_SIGNALS)
ownerOnly path = setFileMode path 0o600
#else
ownerOnly path = setPermissions path (setOwnerWritable True (setOwnerReadable True emptyPermissions))
#endif
