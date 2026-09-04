{-| @Program.Foreign.Ownership — owns one evaluation's foreign resources -}
module Pudu.Foreign.Ownership
  ( ForeignResource
  , claimAllOwned
  , ForeignStore
  , claimOwned
  , closeForeignStore
  , newForeignStore
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
import Control.Exception (SomeException, finally, try)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set

{-| One live native resource and the action its declaration says releases it. -}
data ForeignResource = ForeignResource
  { resourceCleanup :: !(IO ())
  , resourceUses :: !Int
  }

{-| The resource claims belonging to one evaluator run. -}
newtype ForeignStore = ForeignStore (TVar (Map Int64 ForeignResource))

newForeignStore :: IO ForeignStore
newForeignStore = ForeignStore <$> newTVarIO Map.empty

{-| Claim one newly returned address. A live address cannot be claimed twice. -}
claimOwned :: ForeignStore -> Int64 -> IO () -> IO Bool
claimOwned (ForeignStore table) address cleanup = atomically $ do
  held <- readTVar table
  if Map.member address held
    then pure False
    else do
      writeTVar table (Map.insert address (ForeignResource cleanup 0) held)
      pure True

{-| Claim everything one call produced, or claim none of it.

    A call may hand back several resources at once — a result and the slots it
    wrote — and a claim that took some of them and failed on the rest would
    leave the program owning things it cannot name. One transaction decides for
    all of them, and answers with the addresses it refused so the caller can
    give those back to the library.

    An address appearing twice with the same destructor is one resource, so it
    is claimed once rather than counted as a conflict. -}
claimAllOwned :: ForeignStore -> [(Int64, IO ())] -> IO [Int64]
claimAllOwned (ForeignStore table) produced = atomically $ do
  held <- readTVar table
  let taken = foldl remember Map.empty produced
      remember seen (address, cleanup) = Map.insertWith (\_ old -> old) address cleanup seen
      refused = [address | address <- Map.keys taken, Map.member address held]
  if null refused
    then do
      writeTVar table
        (Map.union held (Map.map (\cleanup -> ForeignResource cleanup 0) taken))
      pure []
    else pure refused

{-| Run an action while every distinct address is leased.

    Acquisition is one transaction, so a missing address refuses the complete
    call rather than leaving a prefix leased. `finally` closes the interval even
    if host call assembly raises unexpectedly. -}
withOwned :: ForeignStore -> [Int64] -> IO a -> IO (Maybe a)
withOwned store addresses action = do
  let unique = Set.toList (Set.fromList addresses)
  acquired <- acquire store unique
  if acquired
    then Just <$> action `finally` releaseUses store unique
    else pure Nothing

acquire :: ForeignStore -> [Int64] -> IO Bool
acquire (ForeignStore table) addresses = atomically $ do
  held <- readTVar table
  case traverse (`Map.lookup` held) addresses of
    Nothing -> pure False
    Just resources -> do
      let updated = foldr increment held addresses
      writeTVar table updated
      pure (length resources == length addresses)
 where
  increment address = Map.adjust (\resource -> resource{resourceUses = resourceUses resource + 1}) address

releaseUses :: ForeignStore -> [Int64] -> IO ()
releaseUses (ForeignStore table) addresses = atomically $ do
  held <- readTVar table
  let decrement resource = resource{resourceUses = max 0 (resourceUses resource - 1)}
  writeTVar table (foldr (Map.adjust decrement) held addresses)

{-| Remove a claim for explicit release, waiting until native users finish. -}
takeOwned :: ForeignStore -> Int64 -> IO (Maybe ForeignResource)
takeOwned (ForeignStore table) address = atomically $ do
  held <- readTVar table
  case Map.lookup address held of
    Nothing -> pure Nothing
    Just resource
      | resourceUses resource > 0 -> retry
      | otherwise -> do
          writeTVar table (Map.delete address held)
          pure (Just resource)

{-| Restore a claim when the explicit destructor was never entered. -}
restoreOwned :: ForeignStore -> Int64 -> ForeignResource -> IO ()
restoreOwned (ForeignStore table) address resource = atomically $ do
  held <- readTVar table
  writeTVar table (Map.insert address resource held)

{-| How long teardown waits for native calls still inside a library.

    Generous against any call a program is likely to be in the middle of, and
    finite because teardown has to end. -}
drainPatience :: Int
drainPatience = 5 * 1000 * 1000

{-| Drain and release every resource still owned by this evaluation.

    Teardown waits for leases to close, and then stops waiting. A resource
    still leased when the wait ends is left alone rather than destroyed: another
    thread is inside the library holding that address, and freeing underneath it
    is the fault this whole store exists to prevent. The process is ending, so
    the memory returns anyway — an abandoned resource costs nothing, and a
    destructor called under a live user costs everything.

    Waiting without a bound was the other option and is worse: a program whose
    foreign call never returns would hang on exit with nothing said, which is
    the one failure that hides every other. -}
closeForeignStore :: ForeignStore -> IO ()
closeForeignStore (ForeignStore table) = do
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
