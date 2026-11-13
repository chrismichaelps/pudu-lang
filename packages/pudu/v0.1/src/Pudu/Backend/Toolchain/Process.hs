{-# LANGUAGE CPP #-}

{-| @Pudu.Backend.Toolchain.Process — the bounded runner every native tool
    invocation shares, and the failure vocabulary of the whole toolchain.

    A tool runs from a structural argument list in its own process group; both
    pipes drain concurrently into one budget, and process exit plus both drains
    share one deadline. Every failure mode is a value the caller translates into
    an `E600x` diagnostic.
-}
module Pudu.Backend.Toolchain.Process
  ( ToolchainFailure (..)
  , cleanup
  , problemText
  , runTool
  , runToolOutput
  , timeoutSeconds
  , tryIO
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
import System.Directory (removeFile)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.IO (Handle, hClose)
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

{-| @Backend.Toolchain.Failure — every way building a native artifact can
    fail, kept as data so the caller owns the message vocabulary. The last two
    name a mobile target: its platform SDK was not found, or its output is
    designed but not built. -}
data ToolchainFailure
  = ToolchainNotFound !Text
  | ToolchainInvocation !Text
  | ToolchainTimedOut !Int
  | ToolchainRejected !Text
  | ToolchainPublishFailed !Text
  | ToolchainSdkMissing !Text !Text
  | ToolchainTargetUnbuilt !Text
  deriving stock (Eq, Show)

{-| Run one tool to completion within the deadline. Exit zero answers the
    captured output; any other exit is a rejection carrying it. Acquisition is
    masked until every process and pipe has a cleanup owner. -}
runTool :: FilePath -> [String] -> Int -> IO (Either ToolchainFailure Text)
runTool executable arguments seconds =
  fmap renderToolOutput <$> runToolOutput executable arguments seconds

{-| Keep the output streams separate for callers that parse stdout. -}
runToolOutput :: FilePath -> [String] -> Int -> IO (Either ToolchainFailure (Text, Text, Bool))
runToolOutput executable arguments seconds = mask $ \restore -> do
  capture <- newMVar emptyCapture
  (_, maybeOut, maybeErr, processHandle) <-
    createProcess (proc executable arguments)
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
        Just (ExitSuccess, Right (), Right ()) -> Right . decodedCapture <$> readMVar capture
        Just (ExitFailure _, Right (), Right ()) -> Left . ToolchainRejected . renderToolOutput . decodedCapture <$> readMVar capture
    _ -> stopProcess >> pure (Left (ToolchainInvocation "the compiler's pipes could not be created")))
      `onException` stopProcess
      `finally` closePipes

presentHandles :: Maybe Handle -> Maybe Handle -> [Handle]
presentHandles out err = [handle | Just handle <- [out, err]]

-- Cleanup must remain bounded even when a descendant retains a pipe or the
-- host cannot promptly reap a killed process.
boundedCleanup :: IO () -> IO ()
boundedCleanup action = void (timeout 1000000 action)

{-| @Backend.Toolchain.Capture — the bounded head of what the tool wrote,
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

decodedCapture :: Capture -> (Text, Text, Bool)
decodedCapture captured =
  (decode (captureStdout captured), decode (captureStderr captured), captureTruncated captured)
 where
  decode = Encoding.decodeUtf8With lenientDecode . ByteString.concat . reverse

renderToolOutput :: (Text, Text, Bool) -> Text
renderToolOutput (out, err, truncated) = Text.stripEnd (out <> err <> note)
 where
  note
    | truncated = "\n[compiler output truncated]"
    | otherwise = Text.empty

{-| `PUDU_CC_TIMEOUT` seconds when set and positive, clamped so conversion to
    microseconds cannot overflow; 120 otherwise. -}
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
