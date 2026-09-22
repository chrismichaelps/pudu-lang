{-| @Package.Concurrent — independent package work, run side by side

    Fetching repositories waits on the network and copying packages waits on
    the disk, and neither depends on another package's result, so each item
    runs on its own thread. At most `limit` run at once, which bounds the git
    processes and open files one install holds. Results come back in the
    order of the items, and an exception in one item is raised again in the
    caller after every item has finished, so no thread outlives the call. -}
module Pudu.Package.Concurrent
  ( forConcurrently
  , concurrentLimit
  ) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Concurrent.QSem (newQSem, signalQSem, waitQSem)
import Control.Exception (SomeException, bracket_, throwIO, try)
import Control.Monad (forM)

{-| Enough to hide network latency for a typical project without starting a
    process per dependency of a large one. -}
concurrentLimit :: Int
concurrentLimit = 8

forConcurrently :: Int -> [a] -> (a -> IO b) -> IO [b]
forConcurrently _ [] _ = pure []
forConcurrently _ [item] work = (: []) <$> work item
forConcurrently limit items work = do
  gate <- newQSem (max 1 limit)
  slots <- forM items $ \item -> do
    slot <- newEmptyMVar
    _ <- forkIO (bracket_ (waitQSem gate) (signalQSem gate) (try (work item)) >>= putMVar slot)
    pure slot
  results <- mapM takeMVar slots
  mapM (either (throwIO :: SomeException -> IO b) pure) results
