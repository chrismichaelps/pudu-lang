{-| @Package.Concurrent — bounded concurrent map over independent work

    `forConcurrently limit items work` runs `work` on each item in its own
    thread, at most `limit` at a time, and returns the results in item order.
    If any item throws, the first exception in item order is rethrown after
    every thread has finished. -}
module Pudu.Package.Concurrent
  ( forConcurrently
  , concurrentLimit
  ) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Concurrent.QSem (newQSem, signalQSem, waitQSem)
import Control.Exception (SomeException, bracket_, throwIO, try)
import Control.Monad (forM)

{-| Maximum number of fetches or copies in flight during one install. -}
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
