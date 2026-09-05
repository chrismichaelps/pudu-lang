{-| @Program.Foreign.Ownership — owns one evaluation's foreign resources -}
module Pudu.Foreign.Ownership
  ( ForeignResource
  , claimAllOwnedGenerations
  , claimOwnedGeneration
  , withOwnedGenerations
  , discardOwnedGenerations
  , takeOwnedGeneration
  , claimAllOwned
  , ForeignStore
  , claimOwned
  , closeForeignStore
  , newForeignStore
  , recordForeignDiagnostic
  , takeForeignDiagnostics
  , restoreOwned
  , takeOwned
  , withOwned
  ) where

import Control.Concurrent.STM
  ( STM
  , TVar
  , atomically
  , newTVarIO
  , orElse
  , readTVar
  , registerDelay
  , retry
  , writeTVar
  )
import Control.Exception (SomeException, finally, mask, mask_, try)
import Pudu.Diagnostic (Diagnostic)
import Data.Maybe (isJust)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set

{-| One live native resource and the action its declaration says releases it. -}
data ForeignResource = ForeignResource
  { resourceCleanup :: !(IO ())
  , resourceGeneration :: !Integer
  , resourceUses :: !Int
  }

{-| The resource claims belonging to one evaluator run. -}
data ForeignStore = ForeignStore !(TVar (Map Int64 ForeignResource)) !(TVar Bool) !(TVar [Diagnostic]) !(TVar Integer)

newForeignStore :: IO ForeignStore
newForeignStore = ForeignStore <$> newTVarIO Map.empty <*> newTVarIO False <*> newTVarIO [] <*> newTVarIO 1

{-| Record cleanup problems separately from resource admission and release. -}
recordForeignDiagnostic :: ForeignStore -> Diagnostic -> IO ()
recordForeignDiagnostic (ForeignStore _ _ journal _) problem = atomically $ do
  existing <- readTVar journal
  writeTVar journal (problem : existing)

takeForeignDiagnostics :: ForeignStore -> IO [Diagnostic]
takeForeignDiagnostics (ForeignStore _ _ journal _) = atomically $ do
  existing <- readTVar journal
  writeTVar journal []
  pure (reverse existing)

{-| Claim one newly returned address. A live address cannot be claimed twice. -}
claimOwned :: ForeignStore -> Int64 -> IO () -> IO Bool
claimOwned store address cleanup = isJust <$> claimOwnedGeneration store address cleanup

claimOwnedGeneration :: ForeignStore -> Int64 -> IO () -> IO (Maybe Integer)
claimOwnedGeneration (ForeignStore table closing _ counter) address cleanup = mask_ $ do
  outcome <- atomically $ do
    held <- readTVar table
    closed <- readTVar closing
    if Map.member address held
      then pure (Nothing, False)
      else if closed
        then pure (Nothing, True)
        else do
          generation <- readTVar counter
          writeTVar counter (generation + 1)
          writeTVar table (Map.insert address (ForeignResource cleanup generation 0) held)
          pure (Just generation, False)
  case outcome of
    (accepted, dispose) -> do
      if dispose then cleanupQuietly (ForeignResource cleanup 0 0) else pure ()
      pure accepted

{-| A failed batch returns protected addresses without accepting a prefix. -}
claimAllOwned :: ForeignStore -> [(Int64, IO ())] -> IO (Either [Int64] ())
claimAllOwned store produced = fmap (fmap (const ())) (claimAllOwnedGenerations store produced)

claimAllOwnedGenerations
  :: ForeignStore -> [(Int64, IO ())] -> IO (Either [Int64] [(Int64, Integer)])
claimAllOwnedGenerations (ForeignStore table closing _ counter) produced = atomically $ do
  held <- readTVar table
  closed <- readTVar closing
  let taken = Map.fromList produced
      protected = [address | address <- Map.keys taken, Map.member address held]
  if closed || not (null protected) || Map.size taken /= length produced
    then pure (Left protected)
    else do
      next <- readTVar counter
      let assigned = zip (Map.toAscList taken) [next ..]
          resources = Map.fromList
            [(address, ForeignResource cleanup generation 0)
            | ((address, cleanup), generation) <- assigned]
      writeTVar counter (next + toInteger (Map.size taken))
      writeTVar table (Map.union held resources)
      pure (Right [(address, generation) | ((address, _), generation) <- assigned])

{-| Run an action while every distinct address is leased.

    Acquisition is one transaction, so a missing address refuses the complete
    call rather than leaving a prefix leased. `finally` closes the interval even
    if host call assembly raises unexpectedly. -}
withOwned :: ForeignStore -> [Int64] -> IO a -> IO (Maybe a)
withOwned store addresses = withClaims store [(address, Nothing) | address <- addresses]

withOwnedGenerations :: ForeignStore -> [(Int64, Integer)] -> IO a -> IO (Maybe a)
withOwnedGenerations store claims = withClaims store [(address, Just generation) | (address, generation) <- claims]

withClaims :: ForeignStore -> [(Int64, Maybe Integer)] -> IO a -> IO (Maybe a)
withClaims store claims action = mask $ \restore -> do
  let unique = Set.toList (Set.fromList (map fst claims))
  acquired <- acquire store claims unique
  if acquired
    then Just <$> restore action `finally` releaseUses store unique
    else pure Nothing

acquire :: ForeignStore -> [(Int64, Maybe Integer)] -> [Int64] -> IO Bool
acquire (ForeignStore table closing _ _) claims addresses = atomically $ do
  held <- readTVar table
  closed <- readTVar closing
  let matches (address, expected) = case Map.lookup address held of
        Nothing -> False
        Just resource -> maybe True (== resourceGeneration resource) expected
  if closed || not (all matches claims)
    then pure False
    else do
      writeTVar table (foldr increment held addresses)
      pure True
 where
  increment address = Map.adjust (\resource -> resource{resourceUses = resourceUses resource + 1}) address

releaseUses :: ForeignStore -> [Int64] -> IO ()
releaseUses (ForeignStore table closing _ _) addresses = mask_ $ do
  finished <- atomically $ do
    held <- readTVar table
    closed <- readTVar closing
    let decrement resource = resource{resourceUses = max 0 (resourceUses resource - 1)}
        updated = foldr (Map.adjust decrement) held addresses
        (idle, busy) = Map.partition ((== 0) . resourceUses) updated
    writeTVar table (if closed then busy else updated)
    pure (if closed then Map.elems idle else [])
  mapM_ cleanupQuietly finished

{-| Remove a claim for explicit release, waiting until native users finish. -}
takeOwned :: ForeignStore -> Int64 -> IO (Maybe ForeignResource)
takeOwned store address = takeClaim store address Nothing

takeOwnedGeneration :: ForeignStore -> Int64 -> Integer -> IO (Maybe ForeignResource)
takeOwnedGeneration store address generation = takeClaim store address (Just generation)

takeClaim :: ForeignStore -> Int64 -> Maybe Integer -> IO (Maybe ForeignResource)
takeClaim (ForeignStore table _ _ _) address expected = atomically $ do
  held <- readTVar table
  case Map.lookup address held of
    Nothing -> pure Nothing
    Just resource
      | maybe False (/= resourceGeneration resource) expected -> pure Nothing
      | resourceUses resource > 0 -> retry
      | otherwise -> do
          writeTVar table (Map.delete address held)
          pure (Just resource)

{-| Discard only the exact claims belonging to an unexposed result. -}
discardOwnedGenerations :: ForeignStore -> [(Int64, Integer)] -> IO ()
discardOwnedGenerations store claims = mask_ $ mapM_ discard claims
 where
  discard (address, generation) = do
    found <- takeOwnedGeneration store address generation
    maybe (pure ()) cleanupQuietly found

{-| Restore a claim when the explicit destructor was never entered. -}
restoreOwned :: ForeignStore -> Int64 -> ForeignResource -> IO ()
restoreOwned (ForeignStore table closing _ _) address resource = mask_ $ do
  dispose <- atomically $ do
    held <- readTVar table
    closed <- readTVar closing
    if Map.member address held
      then pure False
      else if closed
        then pure True
        else writeTVar table (Map.insert address resource held) >> pure False
  if dispose then cleanupQuietly resource else pure ()

{-| How long teardown waits for native calls still inside a library.

    Generous against any call a program is likely to be in the middle of, and
    finite because teardown has to end. -}
drainPatience :: Int
drainPatience = 5 * 1000 * 1000

{-| Close admission, drain idle resources, and leave busy cleanup to final leases. -}
closeForeignStore :: ForeignStore -> IO ()
closeForeignStore (ForeignStore table closing _ _) = mask_ $ do
  atomically (writeTVar closing True)
  deadline <- registerDelay drainPatience
  resources <-
    atomically
      ( drain table
          `orElse` ( do
                       expired <- readTVar deadline
                       if expired then drainUnleased table else retry
                   )
      )
  mapM_ cleanupQuietly resources

drain :: TVar (Map Int64 ForeignResource) -> STM [ForeignResource]
drain table = do
  held <- readTVar table
  if any ((> 0) . resourceUses) (Map.elems held)
    then retry
    else do
      writeTVar table Map.empty
      pure (Map.elems held)

{-| Everything nobody is inside, when the wait has ended. -}
drainUnleased :: TVar (Map Int64 ForeignResource) -> STM [ForeignResource]
drainUnleased table = do
  held <- readTVar table
  let (idle, busy) = Map.partition ((== 0) . resourceUses) held
  writeTVar table busy
  pure (Map.elems idle)

cleanupQuietly :: ForeignResource -> IO ()
cleanupQuietly resource = do
  _ <- try (resourceCleanup resource) :: IO (Either SomeException ())
  pure ()
