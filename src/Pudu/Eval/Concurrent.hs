{-| @Eval.Concurrent.Module — threads, channels, and the locks between them -}
module Pudu.Eval.Concurrent
  ( channelClose
  , channelNew
  , channelPending
  , channelReceive
  , channelSend
  , closeAllConcurrent
  , cellNew
  , cellRead
  , cellSwap
  , mutexNew
  , mutexLock
  , mutexUnlock
  , sleepFor
  , threadJoin
  , threadRegister
  ) where

import Control.Concurrent (ThreadId, killThread, threadDelay)
import Control.Concurrent.MVar
  ( MVar
  , newMVar
  , readMVar
  , takeMVar
  , tryPutMVar
  )
import Control.Concurrent.STM
  ( TVar
  , atomically
  , newTVarIO
  , readTVar
  , readTVarIO
  , retry
  , writeTVar
  )
import Control.Exception (SomeException, try)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import Data.Text (Text)
import Pudu.Eval.Io (IoOutcome (..))
import Pudu.Eval.Value (Value)
import System.IO.Unsafe (unsafePerformIO)

{-| @Eval.Concurrent.Running — one thread the program started.

    The outcome is an `MVar` rather than a returned value because a thread's
    answer is not available when the thread is started, and joining is what
    turns it back into one. It carries a message rather than a value: a thread
    started through this runs for what it does, and a thread that failed has to
    be able to say so to whoever joins it. -}
data Running = Running
  { runningThread :: !ThreadId
  , runningOutcome :: !(MVar (Maybe Text))
  }

{-| @Eval.Concurrent.Channel — a queue with a bound.

    Held in a `TVar` rather than an `MVar` because both ends have to wait on a
    condition rather than on a value: a sender waits for room and a receiver
    waits for an item, and neither can be expressed by taking a value out.

    The bound is what makes a channel apply back-pressure. A queue that grew
    without limit would let a fast producer turn a slow consumer into unbounded
    memory, which is the failure a channel exists to prevent rather than to
    postpone. -}
data Channel = Channel
  { channelItems :: !(TVar [Value])
  , channelLimit :: !Int
  , channelClosed :: !(TVar Bool)
  }

threadTable :: IORef (IntMap Running)
{-# NOINLINE threadTable #-}
threadTable = unsafePerformIO (newIORef IntMap.empty)

channelTable :: IORef (IntMap Channel)
{-# NOINLINE channelTable #-}
channelTable = unsafePerformIO (newIORef IntMap.empty)

mutexTable :: IORef (IntMap (MVar ()))
{-# NOINLINE mutexTable #-}
mutexTable = unsafePerformIO (newIORef IntMap.empty)

cellTable :: IORef (IntMap (TVar Value))
{-# NOINLINE cellTable #-}
cellTable = unsafePerformIO (newIORef IntMap.empty)

nextToken :: IORef Int
{-# NOINLINE nextToken #-}
nextToken = unsafePerformIO (newIORef 1)

freshToken :: IO Int
freshToken = atomicModifyIORef' nextToken (\value -> (value + 1, value))

{-| Record a thread that has already been started, and the slot it will report
    into.

    Starting the thread is not done here: running a Pudu closure needs the
    evaluator's own apply, which lives where calls are dispatched. This module
    owns what a started thread is afterwards. -}
threadRegister :: ThreadId -> MVar (Maybe Text) -> IO Int
threadRegister threadId outcome = do
  token <- freshToken
  atomicModifyIORef' threadTable $ \table ->
    (IntMap.insert token (Running{runningThread = threadId, runningOutcome = outcome}) table, ())
  pure token

{-| Wait for a thread to finish, and report what it said if it failed.

    Joining twice answers the same way both times: the outcome is read rather
    than taken, so a scope that joins its children and a caller that already
    joined one do not race for the only copy of the answer. -}
threadJoin :: Int -> IO (IoOutcome ())
threadJoin token = do
  found <- IntMap.lookup token <$> readIORef threadTable
  case found of
    Nothing -> pure (IoFailed "no such thread")
    Just running -> do
      reported <- readMVar (runningOutcome running)
      pure $ case reported of
        Nothing -> IoDone ()
        Just problem -> IoFailed problem

{-| A channel holding at most the given count of items.

    A bound of zero or less is taken as one rather than as none: a channel with
    no room could never be sent to, and a caller writing zero meant the
    smallest useful channel rather than one that deadlocks. -}
channelNew :: Int -> IO Int
channelNew limit = do
  items <- newTVarIO []
  closed <- newTVarIO False
  token <- freshToken
  let channel =
        Channel
          { channelItems = items
          , channelLimit = if limit < 1 then 1 else limit
          , channelClosed = closed
          }
  atomicModifyIORef' channelTable (\table -> (IntMap.insert token channel table, ()))
  pure token

{-| Put an item in, waiting while the channel is full.

    Sending to a closed channel is refused rather than ignored. A sender whose
    items were being dropped would have no way to find out, and a producer that
    kept producing into nothing is exactly the failure worth reporting. -}
channelSend :: Int -> Value -> IO (IoOutcome ())
channelSend token value = withChannel token $ \channel ->
  atomically $ do
    closed <- readTVar (channelClosed channel)
    if closed
      then pure (IoFailed "the channel is closed")
      else do
        items <- readTVar (channelItems channel)
        if length items >= channelLimit channel
          then retry
          else do
            writeTVar (channelItems channel) (items <> [value])
            pure (IoDone ())

{-| Take the next item, waiting while the channel is empty.

    Nothing means the channel is closed and empty, which is what ends a
    receiver's loop. A closed channel still hands out what it already holds:
    closing says no more will arrive, not that what arrived is discarded. -}
channelReceive :: Int -> IO (IoOutcome (Maybe Value))
channelReceive token = withChannel token $ \channel ->
  atomically $ do
    items <- readTVar (channelItems channel)
    case items of
      (first : rest) -> do
        writeTVar (channelItems channel) rest
        pure (IoDone (Just first))
      [] -> do
        closed <- readTVar (channelClosed channel)
        if closed then pure (IoDone Nothing) else retry

{-| How many items are waiting. -}
channelPending :: Int -> IO (IoOutcome Int)
channelPending token = withChannel token $ \channel ->
  IoDone . length <$> readTVarIO (channelItems channel)

{-| Say that nothing more will be sent. -}
channelClose :: Int -> IO (IoOutcome ())
channelClose token = withChannel token $ \channel -> do
  atomically (writeTVar (channelClosed channel) True)
  pure (IoDone ())

withChannel :: Int -> (Channel -> IO (IoOutcome a)) -> IO (IoOutcome a)
withChannel token action = do
  found <- IntMap.lookup token <$> readIORef channelTable
  case found of
    Nothing -> pure (IoFailed "no such channel")
    Just channel -> action channel

{-| A lock, held by at most one thread at a time. -}
mutexNew :: IO Int
mutexNew = do
  lock <- newMVar ()
  token <- freshToken
  atomicModifyIORef' mutexTable (\table -> (IntMap.insert token lock table, ()))
  pure token

{-| Take a lock, waiting until it is free. -}
mutexLock :: Int -> IO (IoOutcome ())
mutexLock token = withMutex token $ \lock -> do
  takeMVar lock
  pure (IoDone ())

{-| Release a lock.

    Releasing one that is not held is not a failure, so a caller unwinding
    through more than one path out of a critical section cannot deadlock the
    program by releasing twice. -}
mutexUnlock :: Int -> IO (IoOutcome ())
mutexUnlock token = withMutex token $ \lock -> do
  _ <- tryPutMVar lock ()
  pure (IoDone ())

withMutex :: Int -> (MVar () -> IO (IoOutcome a)) -> IO (IoOutcome a)
withMutex token action = do
  found <- IntMap.lookup token <$> readIORef mutexTable
  case found of
    Nothing -> pure (IoFailed "no such lock")
    Just lock -> action lock

{-| A value more than one thread may read and replace.

    Swapping is the only write, because it is the one that composes: a read
    followed by a write is two operations, and another thread can act between
    them. A counter built that way loses increments, and loses them only under
    the load that makes the loss hardest to reproduce. -}
cellNew :: Value -> IO Int
cellNew value = do
  holder <- newTVarIO value
  token <- freshToken
  atomicModifyIORef' cellTable (\table -> (IntMap.insert token holder table, ()))
  pure token

cellRead :: Int -> IO (IoOutcome Value)
cellRead token = withCell token (fmap IoDone . readTVarIO)

{-| Replace what a cell holds and answer what it held, in one step nothing can
    come between. -}
cellSwap :: Int -> Value -> IO (IoOutcome Value)
cellSwap token value = withCell token $ \holder ->
  atomically $ do
    held <- readTVar holder
    writeTVar holder value
    pure (IoDone held)

withCell :: Int -> (TVar Value -> IO (IoOutcome a)) -> IO (IoOutcome a)
withCell token action = do
  found <- IntMap.lookup token <$> readIORef cellTable
  case found of
    Nothing -> pure (IoFailed "no such cell")
    Just holder -> action holder

{-| Wait, without holding the machine while doing it. -}
sleepFor :: Int -> IO (IoOutcome ())
sleepFor millis
  | millis <= 0 = pure (IoDone ())
  | otherwise = do
      threadDelay (millis * 1000)
      pure (IoDone ())

{-| Stop every thread still running, so a program that ended does not wait on
    one that will never finish. -}
closeAllConcurrent :: IO ()
closeAllConcurrent = do
  table <- atomicModifyIORef' threadTable (\current -> (IntMap.empty, current))
  mapM_ stopQuietly (IntMap.elems table)
  atomicModifyIORef' channelTable (\_ -> (IntMap.empty, ()))
  atomicModifyIORef' mutexTable (\_ -> (IntMap.empty, ()))
  atomicModifyIORef' cellTable (\_ -> (IntMap.empty, ()))
 where
  stopQuietly running = do
    _ <- try (killThread (runningThread running)) :: IO (Either SomeException ())
    pure ()
