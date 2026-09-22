{-| @Program.Lsp.Scheduler — reading, working, and answering apart -}
module Pudu.Lsp.Scheduler
  ( Step
  , requestCancelled
  , schedule
  ) where

import Control.Concurrent (ThreadId, forkFinally, newEmptyMVar, putMVar, takeMVar, throwTo)
import Control.Concurrent.STM
  ( TVar
  , atomically
  , newTVarIO
  , readTVar
  , retry
  , writeTVar
  )
import Control.Exception (Exception, SomeException, displayException, fromException)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Sequence (Seq, ViewL (..), viewl, (|>))
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import Pudu.Lsp.Protocol (Incoming (..), Message (..), errorResponse)

{-| What handling one message does: from what the server holds before it, what
    it holds after, and the frames to write. -}
type Step state = state -> Message -> IO (state, [Text])

{-| The code a request the client cancelled is answered with. -}
requestCancelled :: Int
requestCancelled = -32800

{-| Work in progress, and what could make it pointless. -}
data Active = Active
  { activeRequest :: !(Maybe Json)
  {-| The document a full-text change was for: a newer change to it makes this
      one's analysis pointless. -}
  , activeChange :: !(Maybe Text)
  , activeThread :: !ThreadId
  }

{-| What the reader tells the worker. -}
data Shared = Shared
  { sharedInbox :: !(TVar (Seq Message))
  {-| Set once reading is over: `Right` at the end of the stream, `Left` with
      the reason when a frame could not be found. -}
  , sharedEnded :: !(TVar (Maybe (Either Text ())))
  , sharedActive :: !(TVar (Maybe Active))
  }

{-| Thrown to work nobody needs any more. -}
data Interrupted = Interrupted
  deriving stock (Show)

instance Exception Interrupted

{-| Serve messages from `next`, writing every frame with `write`, which must
    write a frame whole even when called from two threads at once.

    Reading runs on its own thread, so a message is seen while earlier work is
    still running: a `$/cancelRequest` for a request still waiting answers it
    at once as cancelled and it never runs, and one for the request being
    worked on interrupts that work and answers it as cancelled. A newer full
    text for a document interrupts the analysis of an older one, and an older
    change still waiting behind a newer one for the same document is dropped,
    in both cases only when no request waits between them: only the newest
    text anything will be asked of is read.

    Messages are otherwise handled one at a time, in order, and a request is
    answered exactly once. Interrupted work changes nothing the server holds,
    because the new state is kept only when a step finishes. The result is the
    reason reading stopped when a frame could not be found. -}
schedule :: IO Incoming -> (Text -> IO ()) -> (Text -> IO ()) -> Step state -> state -> IO (Either Text ())
schedule next write logLine step initial = do
  shared <- Shared <$> newTVarIO Seq.empty <*> newTVarIO Nothing <*> newTVarIO Nothing
  -- A reader that fails ends the session as a frame that could not be found
  -- does, rather than leaving the worker waiting for messages forever.
  _ <- forkFinally (readAll shared) $ \outcome -> case outcome of
    Right () -> pure ()
    Left failure -> do
      let reason = Text.strip (Text.pack (displayException failure))
      logLine ("stopping; " <> reason)
      atomically (writeTVar (sharedEnded shared) (Just (Left reason)))
  store <- newIORef initial
  work shared store
 where
  readAll shared = do
    incoming <- next
    case incoming of
      EndOfStream -> atomically (writeTVar (sharedEnded shared) (Just (Right ())))
      Unframed reason -> do
        logLine ("stopping; " <> reason)
        atomically (writeTVar (sharedEnded shared) (Just (Left reason)))
      Unreadable reason -> logLine ("ignored a message; " <> reason) >> readAll shared
      NotForServer -> readAll shared
      Received (Notification "$/cancelRequest" parameters) -> do
        mapM_ (cancel shared) (lookupField "id" parameters)
        readAll shared
      Received message -> do
        interruptible <- atomically $ do
          waiting <- readTVar (sharedInbox shared)
          writeTVar (sharedInbox shared) (enqueue message waiting)
          active <- readTVar (sharedActive shared)
          -- A request already waiting was asked of the text being analysed,
          -- so that analysis is still needed.
          pure $ case (active, changedDocument message) of
            (Just current, Just uri)
              | activeChange current == Just uri, not (any isAnyRequest waiting) -> Just (activeThread current)
            _ -> Nothing
        mapM_ (`throwTo` Interrupted) interruptible
        readAll shared

  cancel shared identity = do
    outcome <- atomically $ do
      waiting <- readTVar (sharedInbox shared)
      case Seq.findIndexL (isRequest identity) waiting of
        Just position -> do
          writeTVar (sharedInbox shared) (Seq.deleteAt position waiting)
          pure (Left ())
        Nothing -> do
          active <- readTVar (sharedActive shared)
          pure $ case active of
            Just current | activeRequest current == Just identity -> Right (Just (activeThread current))
            _ -> Right Nothing
    case outcome of
      Left () -> write (errorResponse identity requestCancelled "the request was cancelled")
      Right thread -> mapM_ (`throwTo` Interrupted) thread

  work shared store = do
    taken <- atomically $ do
      waiting <- readTVar (sharedInbox shared)
      case viewl waiting of
        message :< rest -> do
          writeTVar (sharedInbox shared) rest
          pure (Right message)
        EmptyL -> readTVar (sharedEnded shared) >>= maybe retry (pure . Left)
    case taken of
      Left ended -> pure ended
      Right message -> do
        held <- readIORef store
        result <- running shared message (step held message)
        case result of
          Right (held', frames) -> writeIORef store held' >> mapM_ write frames
          Left failure
            | Just Interrupted <- fromException failure -> case message of
                Request identity _ _ -> write (errorResponse identity requestCancelled "the request was cancelled")
                Notification _ _ -> pure ()
            | otherwise -> excuse message failure >>= mapM_ write
        if isExit message then pure (Right ()) else work shared store

  -- The step runs on a thread of its own, recorded as the active work before
  -- it starts, so an interruption always finds it.
  running shared message action = do
    start <- newEmptyMVar
    done <- newEmptyMVar
    thread <- forkFinally (takeMVar start >> action) (putMVar done)
    atomically (writeTVar (sharedActive shared) (Just (Active (requestOf message) (changedDocument message) thread)))
    putMVar start ()
    result <- takeMVar done
    atomically (writeTVar (sharedActive shared) Nothing)
    pure result

  excuse message failure = do
    logLine (subject <> " failed; " <> detail)
    pure $ case message of
      Request identity _ _ -> [errorResponse identity internalError detail]
      Notification _ _ -> []
   where
    subject = case message of
      Request _ method _ -> method
      Notification method _ -> method
    detail = Text.strip (Text.pack (displayException (failure :: SomeException)))

{-| Queue `message` behind what `waiting` holds. A full-text change makes
    pointless every older change to the same document still waiting with no
    request after it, since nothing will be asked of those texts, so they are
    dropped: the queue holds at most one change per document between two
    requests however fast the client types. -}
enqueue :: Message -> Seq Message -> Seq Message
enqueue message waiting = case changedDocument message of
  Nothing -> waiting |> message
  Just uri ->
    let (since, asked) = Seq.spanr (not . isAnyRequest) waiting
     in (asked <> Seq.filter ((/= Just uri) . changedDocument) since) |> message

changedDocument :: Message -> Maybe Text
changedDocument message = case message of
  Notification "textDocument/didChange" parameters ->
    lookupField "textDocument" parameters >>= lookupField "uri" >>= textOf
  _ -> Nothing

requestOf :: Message -> Maybe Json
requestOf message = case message of
  Request identity _ _ -> Just identity
  Notification _ _ -> Nothing

isRequest :: Json -> Message -> Bool
isRequest identity message = requestOf message == Just identity

isAnyRequest :: Message -> Bool
isAnyRequest message = case message of
  Request {} -> True
  Notification _ _ -> False

isExit :: Message -> Bool
isExit message = case message of
  Notification "exit" _ -> True
  _ -> False

internalError :: Int
internalError = -32603
