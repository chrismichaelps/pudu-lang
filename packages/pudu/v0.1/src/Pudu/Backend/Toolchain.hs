{-# LANGUAGE CPP #-}

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

import Control.Concurrent (ThreadId, forkIOWithUnmask, killThread, newEmptyMVar, putMVar)
import Control.Concurrent.MVar (MVar, modifyMVar_, newMVar, readMVar)
import Control.Exception (IOException, SomeException, displayException, finally, mask, onException, try)
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
  , getPid
  , terminateProcess
  , waitForProcess
  )
#if defined(PUDU_POSIX_SIGNALS)
import System.Posix.Signals (sigKILL, signalProcessGroup)
#endif
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
        invoked <- tryIO (runCompiler executable sourcePath executablePath seconds)
        pure $ case invoked of
          Left problem -> Left (ToolchainInvocation (problemText problem))
          Right result -> result

-- Acquisition is masked until every process and pipe has a cleanup owner.
runCompiler :: FilePath -> FilePath -> FilePath -> Int -> IO (Either ToolchainFailure Text)
runCompiler executable sourcePath executablePath seconds = mask $ \restore -> do
  capture <- newMVar emptyCapture
  (_, maybeOut, maybeErr, processHandle) <-
    createProcess (proc executable (compilerFlags <> ["-o", executablePath, sourcePath]))
      { std_in = NoStream
      , std_out = CreatePipe
      , std_err = CreatePipe
      , create_group = True
      }
  -- Keep the identity before waitForProcess reaps the group leader.
  processId <- getPid processHandle
  let stopProcess = do
#if defined(PUDU_POSIX_SIGNALS)
        case processId of
          Just pid -> void (tryIO (signalProcessGroup sigKILL pid))
          Nothing -> void (tryIO (terminateProcess processHandle))
#else
        let _ = processId
        void (tryIO (terminateProcess processHandle))
#endif
        boundedCleanup (void (tryIO (waitForProcess processHandle)))
      closePipes = mapM_ (boundedCleanup . void . tryIO . hClose) (presentHandles maybeOut maybeErr)
  (case (maybeOut, maybeErr) of
    (Just outHandle, Just errHandle) -> do
      outDrain <- forkDrain capture DrainStdout outHandle
      errDrain <- forkDrain capture DrainStderr errHandle
        `onException` stopDrain outDrain
      let stop = stopProcess >> stopDrain outDrain >> stopDrain errDrain
          waitComplete = do
            exitCode <- waitForProcess processHandle
            outResult <- waitDrain outDrain
            errResult <- waitDrain errDrain
            pure (exitCode, outResult, errResult)
      waited <- restore (timeout (seconds * 1000000) waitComplete) `onException` stop
      case waited of
        Nothing -> stop >> pure (Left (ToolchainTimedOut seconds))
        Just (_, Left problem, _) -> stopProcess >> pure (Left (ToolchainInvocation (Text.pack (displayException problem))))
        Just (_, _, Left problem) -> stopProcess >> pure (Left (ToolchainInvocation (Text.pack (displayException problem))))
        Just (ExitSuccess, Right (), Right ()) -> Right <$> renderedCapture capture
        Just (ExitFailure _, Right (), Right ()) -> Left . ToolchainRejected <$> renderedCapture capture
    _ -> stopProcess >> pure (Left (ToolchainInvocation "the compiler's pipes could not be created")))
      `onException` stopProcess
      `finally` closePipes

presentHandles :: Maybe Handle -> Maybe Handle -> [Handle]
presentHandles out err = [handle | Just handle <- [out, err]]

-- Cleanup must remain bounded even when a descendant retains a pipe or the
-- host cannot promptly reap a killed process.
boundedCleanup :: IO () -> IO ()
boundedCleanup action = void (timeout 1000000 action)

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

data Drain = Drain !ThreadId !(MVar (Either SomeException ()))

forkDrain :: MVar Capture -> DrainStream -> Handle -> IO Drain
forkDrain capture stream handle = do
  done <- newEmptyMVar
  thread <- forkIOWithUnmask $ \unmask -> do
    result <- try (unmask (drainLoop capture stream handle))
    putMVar done result
  pure (Drain thread done)

stopDrain :: Drain -> IO ()
stopDrain (Drain thread done) = boundedCleanup (killThread thread >> void (readMVar done))

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

waitDrain :: Drain -> IO (Either SomeException ())
waitDrain (Drain _ done) = readMVar done

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
    Just seconds | seconds > 0 -> min seconds (maxBound `div` 1000000)
    _ -> defaultTimeoutSeconds

defaultTimeoutSeconds :: Int
defaultTimeoutSeconds = 120

cleanup :: [FilePath] -> IO ()
cleanup paths = mapM_ (\path -> void (tryIO (removeFile path))) paths

tryIO :: IO a -> IO (Either IOException a)
tryIO = try

problemText :: IOException -> Text
problemText = Text.pack . show
