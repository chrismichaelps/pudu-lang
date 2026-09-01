{-| @Eval.Concurrent.Module — threads, channels, and the locks between them -}
module Pudu.Eval.Concurrent
  ( ConcurrentStore
  , channelClose
  , channelNew
  , channelPending
  , channelReceive
  , channelSend
  , closeConcurrentStore
  , cellNew
  , cellRead
  , cellSwap
  , mutexNew
  , mutexLock
  , mutexUnlock
  , newConcurrentStore
  , sleepFor
  , threadJoin
  , threadRegister
  ) where

import Control.Concurrent (ThreadId, killThread, myThreadId, threadDelay)
import Control.Concurrent.MVar
  ( MVar
  , readMVar
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
import Data.Sequence (Seq, ViewL (..), (|>))
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Pudu.Eval.Io (IoOutcome (..))
import Pudu.Eval.Value (Value)

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
  { channelItems :: !(TVar (Seq Value))
  , channelLimit :: !Int
  , channelClosed :: !(TVar Bool)
  }

newtype Mutex = Mutex
  { mutexOwner :: TVar (Maybe ThreadId)
  }

data ConcurrentStore = ConcurrentStore
  { threadTable :: !(IORef (IntMap Running))
  , channelTable :: !(IORef (IntMap Channel))
  , mutexTable :: !(IORef (IntMap Mutex))
  , cellTable :: !(IORef (IntMap (TVar Value)))
  , concurrentNextToken :: !(IORef Int)
  }

newConcurrentStore :: IO ConcurrentStore
newConcurrentStore =
  ConcurrentStore
    <$> newIORef IntMap.empty
    <*> newIORef IntMap.empty
    <*> newIORef IntMap.empty
    <*> newIORef IntMap.empty
    <*> newIORef 1

freshToken :: ConcurrentStore -> IO Int
freshToken store =
  atomicModifyIORef' (concurrentNextToken store) (\value -> (value + 1, value))

{-| Record a thread that has already been started, and the slot it will report
    into.

    Starting the thread is not done here: running a Pudu closure needs the
    evaluator's own apply, which lives where calls are dispatched. This module
    owns what a started thread is afterwards. -}
threadRegister :: ConcurrentStore -> ThreadId -> MVar (Maybe Text) -> IO Int
threadRegister store threadId outcome = do
  token <- freshToken store
  atomicModifyIORef' (threadTable store) $ \table ->
    (IntMap.insert token (Running{runningThread = threadId, runningOutcome = outcome}) table, ())
  pure token

{-| Wait for a thread to finish, and report what it said if it failed.

    Joining twice answers the same way both times: the outcome is read rather
    than taken, so a scope that joins its children and a caller that already
    joined one do not race for the only copy of the answer. -}
threadJoin :: ConcurrentStore -> Int -> IO (IoOutcome ())
threadJoin store token = do
  found <- IntMap.lookup token <$> readIORef (threadTable store)
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
channelNew :: ConcurrentStore -> Int -> IO Int
channelNew store limit = do
  items <- newTVarIO Seq.empty
  closed <- newTVarIO False
  token <- freshToken store
  let channel =
        Channel
          { channelItems = items
          , channelLimit = if limit < 1 then 1 else limit
          , channelClosed = closed
          }
  atomicModifyIORef' (channelTable store) (\table -> (IntMap.insert token channel table, ()))
  pure token

{-| Put an item in, waiting while the channel is full.

    Sending to a closed channel is refused rather than ignored. A sender whose
    items were being dropped would have no way to find out, and a producer that
    kept producing into nothing is exactly the failure worth reporting. -}
channelSend :: ConcurrentStore -> Int -> Value -> IO (IoOutcome ())
channelSend store token value = withChannel store token $ \channel ->
  atomically $ do
    closed <- readTVar (channelClosed channel)
    if closed
      then pure (IoFailed "the channel is closed")
      else do
        items <- readTVar (channelItems channel)
        if length items >= channelLimit channel
          then retry
          else do
            writeTVar (channelItems channel) (items |> value)
            pure (IoDone ())

{-| Take the next item, waiting while the channel is empty.

    Nothing means the channel is closed and empty, which is what ends a
    receiver's loop. A closed channel still hands out what it already holds:
    closing says no more will arrive, not that what arrived is discarded. -}
channelReceive :: ConcurrentStore -> Int -> IO (IoOutcome (Maybe Value))
channelReceive store token = withChannel store token $ \channel ->
  atomically $ do
    items <- readTVar (channelItems channel)
    case Seq.viewl items of
      first :< rest -> do
        writeTVar (channelItems channel) rest
        pure (IoDone (Just first))
      EmptyL -> do
        closed <- readTVar (channelClosed channel)
        if closed then pure (IoDone Nothing) else retry

{-| How many items are waiting. -}
channelPending :: ConcurrentStore -> Int -> IO (IoOutcome Int)
channelPending store token = withChannel store token $ \channel ->
  IoDone . length <$> readTVarIO (channelItems channel)

{-| Say that nothing more will be sent. -}
channelClose :: ConcurrentStore -> Int -> IO (IoOutcome ())
channelClose store token = withChannel store token $ \channel -> do
  atomically (writeTVar (channelClosed channel) True)
  pure (IoDone ())

withChannel :: ConcurrentStore -> Int -> (Channel -> IO (IoOutcome a)) -> IO (IoOutcome a)
withChannel store token action = do
  found <- IntMap.lookup token <$> readIORef (channelTable store)
  case found of
    Nothing -> pure (IoFailed "no such channel")
    Just channel -> action channel

{-| A lock, held by at most one thread at a time. -}
mutexNew :: ConcurrentStore -> IO Int
mutexNew store = do
  lock <- Mutex <$> newTVarIO Nothing
  token <- freshToken store
  atomicModifyIORef' (mutexTable store) (\table -> (IntMap.insert token lock table, ()))
  pure token

{-| Take a lock, waiting until it is free. -}
mutexLock :: ConcurrentStore -> Int -> IO (IoOutcome ())
mutexLock store token = withMutex store token $ \lock -> do
  owner <- myThreadId
  atomically $ do
    heldBy <- readTVar (mutexOwner lock)
    case heldBy of
      Nothing -> do
        writeTVar (mutexOwner lock) (Just owner)
        pure (IoDone ())
      Just _ -> retry

{-| Release a lock only from the thread that acquired it.

    An ownerless permit would let a double release admit two callers into the
    critical section. Reporting foreign and repeated releases keeps mutual
    exclusion intact and exposes the caller's ownership error. -}
mutexUnlock :: ConcurrentStore -> Int -> IO (IoOutcome ())
mutexUnlock store token = withMutex store token $ \lock -> do
  owner <- myThreadId
  atomically $ do
    heldBy <- readTVar (mutexOwner lock)
    case heldBy of
      Nothing -> pure (IoFailed "the lock is not held")
      Just current
        | current == owner -> do
            writeTVar (mutexOwner lock) Nothing
            pure (IoDone ())
        | otherwise -> pure (IoFailed "the lock is owned by another thread")

withMutex :: ConcurrentStore -> Int -> (Mutex -> IO (IoOutcome a)) -> IO (IoOutcome a)
withMutex store token action = do
  found <- IntMap.lookup token <$> readIORef (mutexTable store)
  case found of
    Nothing -> pure (IoFailed "no such lock")
    Just lock -> action lock

{-| A value more than one thread may read and replace.

    Swapping is the only write, because it is the one that composes: a read
    followed by a write is two operations, and another thread can act between
    them. A counter built that way loses increments, and loses them only under
    the load that makes the loss hardest to reproduce. -}
cellNew :: ConcurrentStore -> Value -> IO Int
cellNew store value = do
  holder <- newTVarIO value
  token <- freshToken store
  atomicModifyIORef' (cellTable store) (\table -> (IntMap.insert token holder table, ()))
  pure token

cellRead :: ConcurrentStore -> Int -> IO (IoOutcome Value)
cellRead store token = withCell store token (fmap IoDone . readTVarIO)

{-| Replace what a cell holds and answer what it held, in one step nothing can
    come between. -}
cellSwap :: ConcurrentStore -> Int -> Value -> IO (IoOutcome Value)
cellSwap store token value = withCell store token $ \holder ->
  atomically $ do
    held <- readTVar holder
    writeTVar holder value
    pure (IoDone held)

withCell :: ConcurrentStore -> Int -> (TVar Value -> IO (IoOutcome a)) -> IO (IoOutcome a)
withCell store token action = do
  found <- IntMap.lookup token <$> readIORef (cellTable store)
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
closeConcurrentStore :: ConcurrentStore -> IO ()
closeConcurrentStore store = do
  table <- atomicModifyIORef' (threadTable store) (\current -> (IntMap.empty, current))
  mapM_ stopQuietly (IntMap.elems table)
  atomicModifyIORef' (channelTable store) (\_ -> (IntMap.empty, ()))
  atomicModifyIORef' (mutexTable store) (\_ -> (IntMap.empty, ()))
  atomicModifyIORef' (cellTable store) (\_ -> (IntMap.empty, ()))
 where
  stopQuietly running = do
    _ <- try (killThread (runningThread running)) :: IO (Either SomeException ())
    pure ()
