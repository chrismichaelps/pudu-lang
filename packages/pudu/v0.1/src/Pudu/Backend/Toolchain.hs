{-| @Pudu.Backend.Toolchain — the host executable path of the native
    toolchain.

    It finds a C11 compiler, invokes it on generated source with a fixed flag
    policy through the shared bounded runner, and publishes the resulting
    executable with a same-filesystem rename. Every failure mode is a value the
    caller translates into an `E600x` diagnostic; nothing here throws for an
    expected condition.
-}
module Pudu.Backend.Toolchain
  ( ToolchainFailure (..)
  , ToolchainRequest (..)
  , compileNative
  , compilerFlags
  ) where

import Control.Exception (finally, mask)
import Control.Monad (void)
import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Backend.Runtime.Host.Compress (compressLibraryMarker)
import Pudu.Backend.Runtime.Host.Foreign (foreignLoaderMarker)
import Pudu.Backend.Runtime.Host.Tls (tlsLibraryMarker)
import Pudu.Backend.Toolchain.HostSources (withHostSourceArguments)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), cleanup, problemText, runTool, timeoutSeconds, tryIO)
import System.Directory (findExecutable, renameFile)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, takeFileName)
import System.IO (hClose, openTempFile)
import System.Info (os)
import System.Process (readProcessWithExitCode)

{-| @Backend.Toolchain.Request — the generated translation unit and where the
    executable must end up. -}
data ToolchainRequest = ToolchainRequest
  { toolchainSource :: !Text
  , toolchainOutput :: !FilePath
  }
  deriving stock (Eq, Show)

{-| Compile the generated C and publish the executable atomically. On success
    the captured compiler output is returned — empty when silent, the warnings
    when there are any — so a caller can assert the generated C is
    warning-free under the fixed policy. -}
compileNative :: ToolchainRequest -> IO (Either ToolchainFailure Text)
compileNative request = do
  compiler <- discoverCompiler
  case compiler of
    Left failure -> pure (Left failure)
    Right executable -> withTemporary executable

 where
  output = toolchainOutput request

  withTemporary executable = mask $ \restore -> do
    created <- tryIO (openTempFile (takeDirectory output) (takeFileName output <> ".pudu-tmp.c"))
    case created of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right (sourcePath, sourceHandle) -> do
        let executablePath = sourcePath <> ".out"
        outcome <-
          restore (do
             compiled <- runCompile executable sourcePath sourceHandle executablePath
             case compiled of
               Left failure -> pure (Left failure)
               Right captured -> do
                 published <- tryIO (renameFile executablePath output)
                 pure $ case published of
                   Left problem -> Left (ToolchainPublishFailed (problemText problem))
                   Right () -> Right captured
          )
            `finally` (void (tryIO (hClose sourceHandle)) >> cleanup [sourcePath, executablePath])
        pure outcome

  runCompile executable sourcePath sourceHandle executablePath = do
    written <- tryIO (do
      ByteString.hPut sourceHandle (Encoding.encodeUtf8 (toolchainSource request))
      hClose sourceHandle)
    case written of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right () -> do
        seconds <- timeoutSeconds
        libraries <- sourceLibraries (toolchainSource request)
        invoked <- tryIO $ withHostSourceArguments (toolchainSource request) $ \hostArguments ->
          runTool executable (compilerFlags <> ["-o", executablePath, sourcePath] <> linkerFlags <> libraries <> hostArguments) seconds
        pure $ case invoked of
          Left problem -> Left (ToolchainInvocation (problemText problem))
          Right result -> result

{-| `PUDU_CC` used as given when set, otherwise `cc` found on `PATH`. -}
discoverCompiler :: IO (Either ToolchainFailure FilePath)
discoverCompiler = do
  override <- lookupEnv "PUDU_CC"
  case override of
    Just value | not (null value) -> pure (Right value)
    _ -> do
      found <- findExecutable "cc"
      pure $ case found of
        Just path -> Right path
        Nothing -> Left (ToolchainNotFound "cc")

{-| The fixed flag policy every native compile uses, mobile targets included. -}
compilerFlags :: [String]
compilerFlags = ["-std=c11", "-O2", "-Wall", "-Wextra"]

{-| After the source, where a linker that reads left to right needs them: the
    math library and the thread library the host parts call. -}
linkerFlags :: [String]
linkerFlags
  | os == "mingw32" = []
  | otherwise = ["-lm", "-pthread"]

{-| The system libraries a program's own C asks for, each named by the line
    that includes its header. A program that never includes one links none.
    The TLS library's flags are the ones the machine's own package
    description gives, since its headers sit outside the default search path
    on some systems; a machine without that description gets the plain names. -}
sourceLibraries :: Text -> IO [String]
sourceLibraries source = do
  secured <- if tlsLibraryMarker `Text.isInfixOf` source then tlsLibraryFlags else pure []
  pure (["-lz" | compressLibraryMarker `Text.isInfixOf` source] <> secured
    <> ["-ldl" | os == "linux", foreignLoaderMarker `Text.isInfixOf` source])

tlsLibraryFlags :: IO [String]
tlsLibraryFlags = do
  described <- tryIO (readProcessWithExitCode "pkg-config" ["--cflags", "--libs", "openssl"] "")
  pure $ case described of
    Right (ExitSuccess, flags, _) | not (null (words flags)) -> words flags
    _ -> ["-lssl", "-lcrypto"]
