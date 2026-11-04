{-| @Pudu.Cli.Memory — present catchable host exhaustion at the executable boundary. -}
module Pudu.Cli.Memory (withMemoryFailure) where

import Control.Exception (AsyncException (HeapOverflow), catchJust)
import Pudu.Diagnostic.Host (memoryFailureMessage)
import System.Exit (exitFailure)
import System.IO (hFlush, hPutStrLn, stderr)

withMemoryFailure :: IO a -> IO a
withMemoryFailure action = catchJust heapOnly action $ \() -> do
  hPutStrLn stderr memoryFailureMessage
  hFlush stderr
  exitFailure
  where
    heapOnly HeapOverflow = Just ()
    heapOnly _ = Nothing
