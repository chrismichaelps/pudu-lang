{-| @Pudu.Backend.Toolchain — the one place the compiler starts another
    process.

    It finds a C11 compiler, invokes it on generated source with a fixed flag
    policy, drains its output under a fixed bound, waits a bounded time, and
    publishes the resulting executable with a same-filesystem rename. Every
    failure mode is a value the caller translates into an `E600x` diagnostic;
    nothing here throws for an expected condition.
-}
module Pudu.Backend.Toolchain
  ( ToolchainFailure (..)
  , ToolchainRequest (..)
  , compileNative
  ) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Concurrent.MVar (MVar, modifyMVar_, newMVar, readMVar)
import Control.Exception (IOException, finally, try)
import Control.Monad (void)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Text.Encoding.Error (lenientDecode)
import System.Directory (findExecutable, removeFile, renameFile)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, takeFileName)
import System.IO (Handle, hClose, openTempFile)
import System.Process
  ( CreateProcess (..)
  , StdStream (..)
  , createProcess
  , proc
  , terminateProcess
  , waitForProcess
  )
import System.Timeout (timeout)
import Text.Read (readMaybe)

{-| @Backend.Toolchain.Request — the generated translation unit and where the
    executable must end up. -}
data ToolchainRequest = ToolchainRequest
  { toolchainSource :: !Text
  , toolchainOutput :: !FilePath
  }
  deriving stock (Eq, Show)

{-| @Backend.Toolchain.Failure — every way invoking the toolchain can fail,
    kept as data so the caller owns the message vocabulary. -}
data ToolchainFailure
  = ToolchainNotFound !Text
  | ToolchainInvocation !Text
  | ToolchainTimedOut !Int
  | ToolchainRejected !Text
  | ToolchainPublishFailed !Text
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

  withTemporary executable = do
    created <- tryIO (openTempFile (takeDirectory output) (takeFileName output <> ".pudu-tmp.c"))
    case created of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right (sourcePath, sourceHandle) -> do
        let executablePath = sourcePath <> ".out"
        outcome <-
          (do
             compiled <- runCompile executable sourcePath sourceHandle executablePath
             case compiled of
               Left failure -> pure (Left failure)
               Right captured -> do
                 published <- tryIO (renameFile executablePath output)
                 pure $ case published of
                   Left problem -> Left (ToolchainPublishFailed (problemText problem))
                   Right () -> Right captured
          )
            `finally` cleanup [sourcePath, executablePath]
        pure outcome

  runCompile executable sourcePath sourceHandle executablePath = do
    written <- tryIO (do
      ByteString.hPut sourceHandle (Encoding.encodeUtf8 (toolchainSource request))
      hClose sourceHandle)
    case written of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right () -> do
        capture <- newMVar emptyCapture
        started <- tryIO (createProcess (proc executable (compilerFlags <> ["-o", executablePath, sourcePath]))
          { std_in = NoStream
          , std_out = CreatePipe
          , std_err = CreatePipe
          })
        case started of
          Left problem -> pure (Left (ToolchainInvocation (problemText problem)))
          Right (_, maybeOut, maybeErr, processHandle) -> case (maybeOut, maybeErr) of
            (Just outHandle, Just errHandle) -> do
              outDone <- forkDrain capture DrainStdout outHandle
              errDone <- forkDrain capture DrainStderr errHandle
              seconds <- timeoutSeconds
              waited <- timeout (seconds * 1000000) (waitForProcess processHandle)
              case waited of
                Nothing -> do
                  terminateProcess processHandle
                  void (waitForProcess processHandle)
                  waitDrain outDone
                  waitDrain errDone
                  pure (Left (ToolchainTimedOut seconds))
                Just ExitSuccess -> do
                  waitDrain outDone
                  waitDrain errDone
                  Right <$> renderedCapture capture
                Just (ExitFailure _) -> do
                  waitDrain outDone
                  waitDrain errDone
                  Left . ToolchainRejected <$> renderedCapture capture
            _ -> do
              terminateProcess processHandle
              void (waitForProcess processHandle)
              pure (Left (ToolchainInvocation "the compiler's pipes could not be created"))

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

compilerFlags :: [String]
compilerFlags = ["-std=c11", "-O2", "-Wall", "-Wextra"]

{-| @Backend.Toolchain.Capture — the bounded head of what the compiler wrote,
    with both streams counted against one combined budget. -}
data Capture = Capture
  { captureStdout :: ![ByteString]
  , captureStderr :: ![ByteString]
  , captureBytes :: !Int
  , captureTruncated :: !Bool
  }

emptyCapture :: Capture
emptyCapture = Capture{captureStdout = [], captureStderr = [], captureBytes = 0, captureTruncated = False}

captureLimit :: Int
captureLimit = 64 * 1024

data DrainStream = DrainStdout | DrainStderr

forkDrain :: MVar Capture -> DrainStream -> Handle -> IO (MVar ())
forkDrain capture stream handle = do
  done <- newEmptyMVar
  void (forkIO (drainLoop capture stream handle `finally` putMVar done ()))
  pure done

drainLoop :: MVar Capture -> DrainStream -> Handle -> IO ()
drainLoop capture stream handle = do
  chunk <- ByteString.hGetSome handle 8192
  if ByteString.null chunk
    then hClose handle
    else do
      modifyMVar_ capture (pure . accumulate stream chunk)
      drainLoop capture stream handle

accumulate :: DrainStream -> ByteString -> Capture -> Capture
accumulate stream chunk captured
  | captureBytes captured >= captureLimit = captured{captureTruncated = True}
  | otherwise =
      let room = captureLimit - captureBytes captured
          kept = ByteString.take room chunk
          truncated = ByteString.length chunk > room
          stored = case stream of
            DrainStdout -> captured{captureStdout = kept : captureStdout captured}
            DrainStderr -> captured{captureStderr = kept : captureStderr captured}
       in stored
            { captureBytes = captureBytes captured + ByteString.length kept
            , captureTruncated = captureTruncated captured || truncated
            }

waitDrain :: MVar () -> IO ()
waitDrain = takeMVar

renderedCapture :: MVar Capture -> IO Text
renderedCapture capture = do
  captured <- readMVar capture
  pure (Text.stripEnd (decode (captureStdout captured) <> decode (captureStderr captured) <> note captured))
 where
  decode = Encoding.decodeUtf8With lenientDecode . ByteString.concat . reverse
  note captured
    | captureTruncated captured = "\n[compiler output truncated]"
    | otherwise = Text.empty

timeoutSeconds :: IO Int
timeoutSeconds = do
  configured <- lookupEnv "PUDU_CC_TIMEOUT"
  pure $ case configured >>= readMaybe of
    Just seconds | seconds > 0 -> seconds
    _ -> defaultTimeoutSeconds

defaultTimeoutSeconds :: Int
defaultTimeoutSeconds = 120

cleanup :: [FilePath] -> IO ()
cleanup paths = mapM_ (\path -> void (tryIO (removeFile path))) paths

tryIO :: IO a -> IO (Either IOException a)
tryIO = try

problemText :: IOException -> Text
problemText = Text.pack . show
