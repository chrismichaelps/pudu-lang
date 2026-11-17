{-| @Foreign.CallbackStore — owns interpreter callback generations, leases,
    and invocation lifetime for one run. -}
module Pudu.Foreign.CallbackStore
  ( CallbackStore
  , CallbackKey
  , callbackKeyWord
  , callbackKeyFromWord
  , CallbackAttempt (..)
  , CallbackUnregistration (..)
  , newCallbackStore
  , registerCallback
  , withCallbackLeases
  , invokeCallback
  , unregisterCallback
  , closeCallbackStore
  ) where

import Control.Applicative ((<|>))
import Control.Concurrent.STM
  ( STM, TVar, atomically, check, modifyTVar', newTVarIO, orElse, readTVar
  , registerDelay, writeTVar )
import Control.Exception (finally, mask, mask_, onException)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, isJust, isNothing, mapMaybe)
import qualified Data.Set as Set
import Foreign.Ptr (WordPtr)

{-| A nonzero generation in a trampoline's owning run. Native code only
    transports this value and never dereferences it. -}
newtype CallbackKey = CallbackKey { callbackKeyWord :: WordPtr }
  deriving stock (Eq, Ord, Show)

callbackKeyFromWord :: WordPtr -> Maybe CallbackKey
callbackKeyFromWord 0 = Nothing
callbackKeyFromWord word = Just (CallbackKey word)

data CallbackAttempt failure result
  = CallbackUnavailable
  | CallbackRetired !Bool
  | CallbackFailed !failure
  | CallbackCompleted !result
  deriving stock (Eq, Show)

data CallbackUnregistration failure
  = CallbackUnknown
  | CallbackUnregistered !(Maybe failure)
  deriving stock (Eq, Show)

{-| A retired entry retains its identity and failure after releasing its
    executable handler. This lets old contexts and repeated unregister
    calls settle without crossing into another registration. -}
data Registration handler failure = Registration
  { registrationHandler :: !(Maybe handler)
  , registrationFailure :: !(Maybe failure)
  , registrationInvocations :: !Int
  , registrationLeases :: !Int
  , registrationRetired :: !Bool
  , registrationWarned :: !Bool
  , registrationObserved :: !Bool
  }

data StoreState handler failure = StoreState
  { storeNext :: !(Maybe WordPtr)
  , storeClosing :: !Bool
  , storeEntries :: !(Map.Map CallbackKey (Registration handler failure))
  }

newtype CallbackStore handler failure = CallbackStore (TVar (StoreState handler failure))

newCallbackStore :: IO (CallbackStore handler failure)
newCallbackStore = CallbackStore <$> newTVarIO (StoreState (Just 1) False Map.empty)

registerCallback :: CallbackStore handler failure -> handler -> IO (Maybe CallbackKey)
registerCallback (CallbackStore state) handler = atomically $ do
  store <- readTVar state
  case storeNext store of
    Just word | not (storeClosing store) -> do
      let key = CallbackKey word
          next = if word == maxBound then Nothing else Just (word + 1)
          entry = Registration (Just handler) Nothing 0 0 False False False
      writeTVar state store{storeNext = next, storeEntries = Map.insert key entry (storeEntries store)}
      pure (Just key)
    _ -> pure Nothing

{-| Lease admission is atomic over the whole call. Multiple appearances of
    the same token share the same lease for this dispatch. -}
withCallbackLeases
  :: CallbackStore handler failure -> [CallbackKey] -> IO a -> IO (Maybe a)
withCallbackLeases _ [] action = Just <$> action
withCallbackLeases (CallbackStore state) keys action = mask $ \restore -> do
  let distinct = Set.toList (Set.fromList keys)
      alterLeases delta store = store
        {storeEntries = foldr (Map.adjust (changeLeases delta)) (storeEntries store) distinct}
      changeLeases delta entry = reclaim (entry{registrationLeases = registrationLeases entry + delta})
  admitted <- atomically $ do
    store <- readTVar state
    let live key = maybe False (not . registrationRetired) (Map.lookup key (storeEntries store))
    if storeClosing store || not (all live distinct)
      then pure False
      else writeTVar state (alterLeases 1 store) >> pure True
  if admitted
    then Just <$> (restore action `finally` atomically (modifyTVar' state (alterLeases (-1))))
    else pure Nothing

{-| Only an admitted invocation runs the handler. Pinning and unpinning are
    masked, including when Haskell work is interrupted before the adapter
    returns its callback failure. -}
invokeCallback
  :: CallbackStore handler failure
  -> CallbackKey
  -> (handler -> IO (Either failure result))
  -> IO (CallbackAttempt failure result)
invokeCallback (CallbackStore state) key action = mask $ \restore -> do
  admission <- atomically (admitInvocation state key)
  case admission of
    Left declined -> pure declined
    Right handler -> do
      answer <- restore (action handler) `onException` (leave Nothing >> pure ())
      case answer of
        Left failure -> CallbackFailed . fromMaybe failure <$> leave (Just failure)
        Right result -> leave Nothing >> pure (CallbackCompleted result)
 where
  leave failure = atomically $ do
    store <- readTVar state
    case Map.lookup key (storeEntries store) of
      Nothing -> pure failure
      Just entry -> do
        let retained = registrationFailure entry <|> failure
        modifyEntry state key $ \_ ->
          reclaim (entry
            { registrationInvocations = registrationInvocations entry - 1
            , registrationFailure = retained
            })
        pure retained

admitInvocation
  :: TVar (StoreState handler failure) -> CallbackKey
  -> STM (Either (CallbackAttempt failure result) handler)
admitInvocation state key = do
  store <- readTVar state
  if storeClosing store then pure (Left CallbackUnavailable) else
    case Map.lookup key (storeEntries store) of
      Just entry | registrationRetired entry -> do
        let warn = not (registrationWarned entry)
        modifyEntry state key (\registration -> registration{registrationWarned = True})
        pure (Left (CallbackRetired warn))
      Just entry
        | isNothing (registrationFailure entry)
        , Just handler <- registrationHandler entry -> do
            modifyEntry state key $ \registration ->
              registration{registrationInvocations = registrationInvocations registration + 1}
            pure (Right handler)
      _ -> pure (Left CallbackUnavailable)

{-| Publish retirement before waiting, so even a cancelled waiter leaves the
    token retired. An unregister inside its own invocation never waits. -}
unregisterCallback
  :: CallbackStore handler failure -> Set.Set CallbackKey -> CallbackKey
  -> IO (CallbackUnregistration failure)
unregisterCallback (CallbackStore state) ancestry key = mask_ $ do
  atomically (modifyEntry state key (\entry -> reclaim (entry{registrationRetired = True})))
  atomically $ do
    store <- readTVar state
    case Map.lookup key (storeEntries store) of
      Nothing -> pure CallbackUnknown
      Just entry -> do
        check (Set.member key ancestry || registrationInvocations entry == 0)
        let failure = registrationFailure entry
        if isJust failure
          then modifyEntry state key (\registration -> registration{registrationObserved = True})
          else pure ()
        pure (CallbackUnregistered failure)

{-| Teardown closes admission first and bounds the wait for in-flight
    invocations. Late calls observe the closed store without running a
    handler, including after the entries and their captures are dropped. -}
closeCallbackStore :: Int -> CallbackStore handler failure -> IO [failure]
closeCallbackStore waitMicros (CallbackStore state) = mask_ $ do
  started <- atomically $ do
    store <- readTVar state
    if storeClosing store then pure False else do
      writeTVar state store{storeClosing = True, storeNext = Nothing}
      pure True
  if not started then pure [] else do
    deadline <- registerDelay waitMicros
    let drain = do
          store <- readTVar state
          writeTVar state store{storeEntries = Map.empty}
          pure (mapMaybe unobserved (Map.elems (storeEntries store)))
        waitForInvocations = do
          store <- readTVar state
          check (all ((== 0) . registrationInvocations) (Map.elems (storeEntries store)))
        waitForDeadline = readTVar deadline >>= check
    atomically ((waitForInvocations `orElse` waitForDeadline) >> drain)
      `onException` atomically (drain >> pure ())
 where
  unobserved entry
    | registrationObserved entry = Nothing
    | otherwise = registrationFailure entry

modifyEntry
  :: TVar (StoreState handler failure) -> CallbackKey
  -> (Registration handler failure -> Registration handler failure) -> STM ()
modifyEntry state key change = modifyTVar' state $ \store ->
  store{storeEntries = Map.adjust change key (storeEntries store)}

reclaim :: Registration handler failure -> Registration handler failure
reclaim entry
  | registrationRetired entry
  , registrationInvocations entry == 0
  , registrationLeases entry == 0 = entry{registrationHandler = Nothing}
  | otherwise = entry
