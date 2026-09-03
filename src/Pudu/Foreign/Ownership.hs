{-| @Program.Foreign.Ownership — owns one evaluation's foreign resources -}
module Pudu.Foreign.Ownership
  ( ForeignResource
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
  , readTVar
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

{-| Drain and release every resource still owned by this evaluation. -}
closeForeignStore :: ForeignStore -> IO ()
closeForeignStore (ForeignStore table) = do
  resources <- atomically (drain table)
  mapM_ cleanupQuietly resources

drain :: TVar (Map Int64 ForeignResource) -> STM [ForeignResource]
drain table = do
  held <- readTVar table
  if any ((> 0) . resourceUses) (Map.elems held)
    then retry
    else do
      writeTVar table Map.empty
      pure (Map.elems held)

cleanupQuietly :: ForeignResource -> IO ()
cleanupQuietly resource = do
  _ <- try (resourceCleanup resource) :: IO (Either SomeException ())
  pure ()
