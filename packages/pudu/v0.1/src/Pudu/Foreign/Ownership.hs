{-| @Program.Foreign.Ownership — owns one evaluation's foreign resources -}
module Pudu.Foreign.Ownership
  ( ForeignResource
  , claimAllOwnedGenerations
  , claimCountedGeneration
  , claimOwnedGeneration
  , withOwnedGenerations
  , discardOwnedGenerations
  , takeOwnedGeneration
  , takeCountedGeneration
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

{-| The resource claims belonging to one evaluator run.

    Two tables, because two libraries mean two things by handing back the same
    address. Most mean "this is yours now", and a second claim on a live address
    is a mistake worth refusing — that is the first table, keyed by address.

    A reference-counted library means "here is another reference", and cairo,
    GObject, CoreFoundation and COM all work that way: `g_object_ref` returns
    the pointer it was given, and each reference owes its own unref. Those
    cannot be keyed by address at all, since several live claims share one. They
    are keyed by the generation, which is unique per claim by construction.

    Keeping them apart leaves every owned path exactly as it was, rather than
    loosening the rule that protects the common case in order to admit the
    other. Nothing diagnoses a library declared owned in one function and
    counted in another; that is a mis-declaration this side cannot see. -}
data ForeignStore = ForeignStore
  !(TVar (Map Int64 ForeignResource))
  !(TVar Bool)
  !(TVar [Diagnostic])
  !(TVar Integer)
  !(TVar (Map Integer (Int64, ForeignResource)))

newForeignStore :: IO ForeignStore
newForeignStore =
  ForeignStore
    <$> newTVarIO Map.empty
    <*> newTVarIO False
    <*> newTVarIO []
    <*> newTVarIO 1
    <*> newTVarIO Map.empty

{-| Which table a lease is held in, decided once when it is taken. -}
data Lease = OwnedLease !Int64 | CountedLease !Integer
  deriving stock (Eq, Ord)

{-| Record cleanup problems separately from resource admission and release. -}
recordForeignDiagnostic :: ForeignStore -> Diagnostic -> IO ()
recordForeignDiagnostic (ForeignStore _ _ journal _ _) problem = atomically $ do
  existing <- readTVar journal
  writeTVar journal (problem : existing)

takeForeignDiagnostics :: ForeignStore -> IO [Diagnostic]
takeForeignDiagnostics (ForeignStore _ _ journal _ _) = atomically $ do
  existing <- readTVar journal
  writeTVar journal []
  pure (reverse existing)

{-| Claim one newly returned address. A live address cannot be claimed twice. -}
claimOwned :: ForeignStore -> Int64 -> IO () -> IO Bool
claimOwned store address cleanup = isJust <$> claimOwnedGeneration store address cleanup

claimOwnedGeneration :: ForeignStore -> Int64 -> IO () -> IO (Maybe Integer)
claimOwnedGeneration (ForeignStore table closing _ counter _) address cleanup = mask_ $ do
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

{-| Claim another reference to something already referenced.

    Always admitted while the store is open: the address of a second reference
    is the address of the first, and refusing that is refusing what a
    reference-counted library does. Each claim owes one release, so two
    references release twice. -}
claimCountedGeneration :: ForeignStore -> Int64 -> IO () -> IO (Maybe Integer)
claimCountedGeneration (ForeignStore _ closing _ counter counted) address cleanup = mask_ $ do
  outcome <- atomically $ do
    closed <- readTVar closing
    if closed
      then pure Nothing
      else do
        generation <- readTVar counter
        writeTVar counter (generation + 1)
        held <- readTVar counted
        writeTVar counted (Map.insert generation (address, ForeignResource cleanup generation 0) held)
        pure (Just generation)
  case outcome of
    Nothing -> do
      cleanupQuietly (ForeignResource cleanup 0 0)
      pure Nothing
    Just generation -> pure (Just generation)

{-| A failed batch returns protected addresses without accepting a prefix. -}
claimAllOwned :: ForeignStore -> [(Int64, IO ())] -> IO (Either [Int64] ())
claimAllOwned store produced = fmap (fmap (const ())) (claimAllOwnedGenerations store produced)

claimAllOwnedGenerations
  :: ForeignStore -> [(Int64, IO ())] -> IO (Either [Int64] [(Int64, Integer)])
claimAllOwnedGenerations (ForeignStore table closing _ counter _) produced = atomically $ do
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
  acquired <- acquire store claims
  case acquired of
    Nothing -> pure Nothing
    Just leases -> Just <$> restore action `finally` releaseLeases store leases

{-| Lease every claim, or none. A claim names a table by where it is found, so
    two references sharing one address are two leases rather than one. -}
acquire :: ForeignStore -> [(Int64, Maybe Integer)] -> IO (Maybe [Lease])
acquire (ForeignStore table closing _ _ counted) claims = atomically $ do
  held <- readTVar table
  references <- readTVar counted
  closed <- readTVar closing
  let found (address, expected) = case Map.lookup address held of
        Just resource
          | maybe True (== resourceGeneration resource) expected -> Just (OwnedLease address)
        _ -> case expected of
          Nothing -> Nothing
          Just generation -> case Map.lookup generation references of
            Just (owner, _) | owner == address -> Just (CountedLease generation)
            _ -> Nothing
      resolved = map found claims
  if closed || any (== Nothing) resolved
    then pure Nothing
    else do
      let leases = Set.toList (Set.fromList [lease | Just lease <- resolved])
      writeTVar table (foldr incrementOwned held leases)
      writeTVar counted (foldr incrementCounted references leases)
      pure (Just leases)
 where
  incrementOwned lease = case lease of
    OwnedLease address -> Map.adjust busier address
    CountedLease _ -> id
  incrementCounted lease = case lease of
    CountedLease generation -> Map.adjust (fmap busier) generation
    OwnedLease _ -> id
  busier resource = resource{resourceUses = resourceUses resource + 1}

releaseLeases :: ForeignStore -> [Lease] -> IO ()
releaseLeases (ForeignStore table closing _ _ counted) leases = mask_ $ do
  finished <- atomically $ do
    held <- readTVar table
    references <- readTVar counted
    closed <- readTVar closing
    let updated = foldr decrementOwned held leases
        updatedCounted = foldr decrementCounted references leases
        (idle, busy) = Map.partition ((== 0) . resourceUses) updated
        (idleCounted, busyCounted) = Map.partition ((== 0) . resourceUses . snd) updatedCounted
    writeTVar table (if closed then busy else updated)
    writeTVar counted (if closed then busyCounted else updatedCounted)
    pure
      ( if closed
          then Map.elems idle <> map snd (Map.elems idleCounted)
          else []
      )
  mapM_ cleanupQuietly finished
 where
  decrementOwned lease = case lease of
    OwnedLease address -> Map.adjust idler address
    CountedLease _ -> id
  decrementCounted lease = case lease of
    CountedLease generation -> Map.adjust (fmap idler) generation
    OwnedLease _ -> id
  idler resource = resource{resourceUses = max 0 (resourceUses resource - 1)}

{-| Remove a claim for explicit release, waiting until native users finish. -}
takeOwned :: ForeignStore -> Int64 -> IO (Maybe ForeignResource)
takeOwned store address = takeClaim store address Nothing

takeOwnedGeneration :: ForeignStore -> Int64 -> Integer -> IO (Maybe ForeignResource)
takeOwnedGeneration store address generation = takeClaim store address (Just generation)

takeClaim :: ForeignStore -> Int64 -> Maybe Integer -> IO (Maybe ForeignResource)
takeClaim (ForeignStore table _ _ _ _) address expected = atomically $ do
  held <- readTVar table
  case Map.lookup address held of
    Nothing -> pure Nothing
    Just resource
      | maybe False (/= resourceGeneration resource) expected -> pure Nothing
      | resourceUses resource > 0 -> retry
      | otherwise -> do
          writeTVar table (Map.delete address held)
          pure (Just resource)

{-| Release one reference, leaving any others at that address alone.

    Waits while a native call is inside this reference, the way an owned claim
    does, and removes exactly the one named — its address may still be live
    under other references, and is not consulted. -}
takeCountedGeneration :: ForeignStore -> Int64 -> Integer -> IO (Maybe ForeignResource)
takeCountedGeneration (ForeignStore _ _ _ _ counted) address generation = atomically $ do
  references <- readTVar counted
  case Map.lookup generation references of
    Nothing -> pure Nothing
    Just (owner, resource)
      | owner /= address -> pure Nothing
      | resourceUses resource > 0 -> retry
      | otherwise -> do
          writeTVar counted (Map.delete generation references)
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
restoreOwned (ForeignStore table closing _ _ _) address resource = mask_ $ do
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
closeForeignStore (ForeignStore table closing _ _ counted) = mask_ $ do
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
  {-| Every outstanding reference owes its own release, so teardown releases
      each one rather than the address once. -}
  references <-
    atomically
      ( drainCounted counted
          `orElse` ( do
                       expired <- readTVar deadline
                       if expired then drainUnleasedCounted counted else retry
                   )
      )
  mapM_ cleanupQuietly (resources <> references)

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

drainCounted :: TVar (Map Integer (Int64, ForeignResource)) -> STM [ForeignResource]
drainCounted counted = do
  held <- readTVar counted
  if any ((> 0) . resourceUses . snd) (Map.elems held)
    then retry
    else do
      writeTVar counted Map.empty
      pure (map snd (Map.elems held))

drainUnleasedCounted :: TVar (Map Integer (Int64, ForeignResource)) -> STM [ForeignResource]
drainUnleasedCounted counted = do
  held <- readTVar counted
  let (idle, busy) = Map.partition ((== 0) . resourceUses . snd) held
  writeTVar counted busy
  pure (map snd (Map.elems idle))

cleanupQuietly :: ForeignResource -> IO ()
cleanupQuietly resource = do
  _ <- try (resourceCleanup resource) :: IO (Either SomeException ())
  pure ()
