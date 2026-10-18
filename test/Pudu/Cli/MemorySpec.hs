{-| @Test.Cli.MemorySpec — heap exhaustion must not swallow cancellation. -}
module Pudu.Cli.MemorySpec (memoryProperties) where

import Control.Exception (AsyncException (..), bracket, finally, throwIO, try)
import Data.Text (Text)
import qualified Data.Text.IO as TextIO
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import Pudu.Cli.Memory (withMemoryFailure)
import Pudu.Diagnostic.Host (memoryFailureMessage)
import System.Exit (ExitCode (..))
import System.IO (SeekMode (AbsoluteSeek), hClose, hFlush, hSeek, openTempFile, stderr)
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, (===))

memoryProperties :: [(String, IO Property)]
memoryProperties = [("host memory failure preserves success and other asynchronous exceptions", testMemory)]

testMemory :: IO Property
testMemory = do
  (normal, normalError) <- capture (withMemoryFailure (pure (7 :: Int)))
  (failed, failureError) <- capture
    (try (withMemoryFailure (throwIO HeapOverflow)) :: IO (Either ExitCode ()))
  propagated <- traverse check [StackOverflow, ThreadKilled, UserInterrupt]
  pure $ conjoin
    [ normal === 7, normalError === "", failed === Left (ExitFailure 1)
    , failureError === "pudu: memory allocation failed\n"
    , memoryFailureMessage === "pudu: memory allocation failed", conjoin propagated
    ]
  where
    check exception = do
      (result, output) <- capture
        (try (withMemoryFailure (throwIO exception)) :: IO (Either AsyncException ()))
      pure (conjoin [result === Left exception, output === ""])

capture :: IO a -> IO (a, Text)
capture action = withSystemTempDirectory "pudu-memory" $ \root ->
  bracket (openTempFile root "stderr") (hClose . snd) $ \(_, handle) ->
    bracket (hDuplicate stderr) hClose $ \saved -> do
      hDuplicateTo handle stderr
      result <- action `finally` (hFlush stderr >> hDuplicateTo saved stderr)
      hFlush handle
      hSeek handle AbsoluteSeek 0
      output <- TextIO.hGetContents handle
      pure (result, output)
