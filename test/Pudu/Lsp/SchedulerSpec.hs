{-| @Test.Lsp.Scheduler — reading keeps up while work is blocked -}
module Pudu.Lsp.SchedulerSpec (schedulerProperties) where

import Control.Concurrent (forkIO, newChan, newEmptyMVar, putMVar, readChan, takeMVar, writeChan)
import Data.IORef (atomicModifyIORef', newIORef, readIORef)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Json (Json (..), lookupField, parse)
import Pudu.Lsp.Protocol (Incoming (..), Message (..), response)
import Pudu.Lsp.Scheduler (requestCancelled, schedule)
import System.Timeout (timeout)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

schedulerProperties :: [(String, IO Property)]
schedulerProperties =
  [ ("the reader sees cancellations and edits while work is blocked", testBlockedWork)
  ]

{-| Work is blocked on gates the test opens, never on time, so what the
    scheduler did is known exactly when each gate opens. -}
testBlockedWork :: IO Property
testBlockedWork = do
  incoming <- newChan
  written <- newChan
  entered <- newChan
  gates <- newChan
  seen <- newIORef ([] :: [Text])
  finished <- newEmptyMVar
  let step count message = case message of
        Request identity method _ -> do
          writeChan entered method
          if method == "blocked" then readChan gates else pure ()
          pure (count, [response identity (JsonNumber (fromIntegral count))])
        Notification "textDocument/didChange" parameters -> do
          let version = case lookupField "textDocument" parameters >>= lookupField "version" of
                Just (JsonNumber value) -> value
                _ -> 0
          atomicModifyIORef' seen (\versions -> (versions <> [Text.pack (show (round version :: Int))], ()))
          pure (count + 1, [])
        Notification _ _ -> pure (count, [])
      send = writeChan incoming . Received
      request identity method = send (Request (JsonNumber identity) method (JsonObject []))
      cancel identity = send (Notification "$/cancelRequest" (JsonObject [("id", JsonNumber identity)]))
      change version =
        send
          ( Notification "textDocument/didChange"
              (JsonObject [("textDocument", JsonObject [("uri", JsonText "file:///a.pudu"), ("version", JsonNumber version)])])
          )
      reply = do
        body <- readChan written
        pure (parse body)
      within action = timeout 5000000 action
  _ <- forkIO (schedule (readChan incoming) (writeChan written) (const (pure ())) step (0 :: Int) >>= putMVar finished)
  -- An active request is interrupted and answered as cancelled.
  request 1 "blocked"
  firstEntered <- within (readChan entered)
  cancel 1
  cancelledActive <- within reply
  -- A queued request is answered as cancelled and never runs; changes waiting
  -- behind a newer one with no request between them are skipped.
  request 2 "blocked"
  secondEntered <- within (readChan entered)
  request 3 "queued"
  cancel 3
  cancelledQueued <- within reply
  mapM_ change [1, 2, 3]
  -- A request queued and cancelled after the changes is answered only once
  -- the reader has queued everything before it, so the changes are waiting
  -- when the blocked request is released.
  request 5 "marker"
  cancel 5
  cancelledMarker <- within reply
  writeChan gates ()
  secondAnswer <- within reply
  request 4 "plain"
  fourthEntered <- within (readChan entered)
  fourthAnswer <- within reply
  send (Notification "exit" (JsonObject []))
  ended <- within (takeMVar finished)
  versions <- readIORef seen
  pure $ conjoin
    [ counterexample "the blocked request started" (firstEntered === Just "blocked")
    , counterexample "an active request is answered as cancelled" (errorOf cancelledActive === Just (1, requestCancelled))
    , counterexample "the next request started" (secondEntered === Just "blocked")
    , counterexample "a queued request is answered as cancelled at once" (errorOf cancelledQueued === Just (3, requestCancelled))
    , counterexample "the blocked request is answered once it finishes" (fmap (>>= idOf) secondAnswer === Just (Just 2))
    , counterexample ("only the newest waiting change was analysed: " <> show versions) (versions === ["3"])
    , counterexample "the cancelled queued request never ran" (fourthEntered === Just "plain")
    , counterexample "a later request is answered" (fmap (>>= idOf) fourthAnswer === Just (Just 4))
    , counterexample "exit ends the session" (ended === Just (Right ()))
    , counterexample "the marker was answered as cancelled" (errorOf cancelledMarker === Just (5, requestCancelled))
    ]
 where
  idOf message = case lookupField "id" message of
    Just (JsonNumber value) -> Just (round value :: Int)
    _ -> Nothing
  errorOf found = do
    message <- found
    identity <- message >>= idOf
    JsonNumber code <- message >>= lookupField "error" >>= lookupField "code"
    pure (identity, round code :: Int)
