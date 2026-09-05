{-| What the store admits, refuses, and releases.

    A batch is all of it or none of it, an address is not an identity, and a
    claim nothing above the boundary can name is discarded rather than left
    behind. These reach the store directly: the paths they cover are the ones a
    passing foreign call never takes. -}
module Pudu.Foreign.OwnershipSpec (ownershipProperties) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar, throwTo)
import Control.Exception (AsyncException (ThreadKilled))
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Int (Int64)
import Data.List (sort)
import Pudu.Foreign.Ownership
  ( claimAllOwnedGenerations
  , claimOwnedGeneration
  , closeForeignStore
  , discardOwnedGenerations
  , newForeignStore
  , takeOwnedGeneration
  , withOwnedGenerations
  )
import System.Timeout (timeout)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

ownershipProperties :: [(String, IO Property)]
ownershipProperties =
  [ ("a batch naming one address twice is refused whole", testDuplicateBatch)
  , ("a batch touching a held address leaves that claim alone", testProtectedBatch)
  , ("a batch that is refused releases nothing", testRefusedBatchKeepsCleanup)
  , ("an address reused after release does not revive the old claim", testStaleGeneration)
  , ("a discarded claim is released once and only its own", testDiscardOwnClaims)
  , ("a closing store admits nothing and releases what it turns away", testClosedAdmission)
  , ("a lease cancelled mid-call is still given back", testInterruptedLease)
  ]

{-| A cleanup that records that it ran, so a leak and a double release are both
    visible as a count rather than inferred. -}
newtype Releases = Releases (IORef [Int64])

newReleases :: IO Releases
newReleases = Releases <$> newIORef []

releasing :: Releases -> Int64 -> IO ()
releasing (Releases held) address = atomicModifyIORef' held (\seen -> (address : seen, ()))

released :: Releases -> IO [Int64]
released (Releases held) = sort <$> readIORef held

{-| Two products at one address cannot both be claimed, and coalescing them
    would leave one destructor obligation for two resources. -}
testDuplicateBatch :: IO Property
testDuplicateBatch = do
  store <- newForeignStore
  releases <- newReleases
  outcome <- claimAllOwnedGenerations store [(4096, releasing releases 4096), (4096, releasing releases 4096)]
  after <- released releases
  reclaimed <- claimOwnedGeneration store 4096 (releasing releases 4096)
  pure
    ( conjoin
        [ counterexample "the batch is refused" (property (isRefusal outcome))
        , counterexample "no address is named protected" (refusedAddresses outcome === [])
        , counterexample "nothing was released by the refusal" (after === [])
        , counterexample "the address was never inserted" (property (isJustGeneration reclaimed))
        ]
    )

{-| A refused batch names only what the store already held. The caller's own
    fresh products stay its problem, and the existing claim is untouched. -}
testProtectedBatch :: IO Property
testProtectedBatch = do
  store <- newForeignStore
  releases <- newReleases
  held <- claimOwnedGeneration store 4096 (releasing releases 4096)
  outcome <-
    claimAllOwnedGenerations
      store
      [(4096, releasing releases 4096), (8192, releasing releases 8192)]
  afterRefusal <- released releases
  survivor <- case held of
    Nothing -> pure Nothing
    Just generation -> takeOwnedGeneration store 4096 generation
  fresh <- claimOwnedGeneration store 8192 (releasing releases 8192)
  pure
    ( conjoin
        [ counterexample "the batch is refused" (property (isRefusal outcome))
        , counterexample "only the held address is named" (refusedAddresses outcome === [4096])
        , counterexample "the refusal released nothing" (afterRefusal === [])
        , counterexample "the existing claim survived" (property (isJustResource survivor))
        , counterexample "the fresh address was never inserted" (property (isJustGeneration fresh))
        ]
    )

{-| A refusal must not free what it turned away: the caller still holds those
    products and is the only side that knows their release obligation. -}
testRefusedBatchKeepsCleanup :: IO Property
testRefusedBatchKeepsCleanup = do
  store <- newForeignStore
  releases <- newReleases
  _ <- claimOwnedGeneration store 4096 (releasing releases 4096)
  _ <- claimAllOwnedGenerations store [(4096, releasing releases 4096)]
  _ <- claimAllOwnedGenerations store [(16384, releasing releases 16384), (16384, releasing releases 16384)]
  after <- released releases
  pure (counterexample "a refusal is not a release" (after === []))

{-| An allocator hands the same address back after a free. The generation is
    what says the old handle names a resource that is gone, so a use and a
    release of it are both refused while the new occupant stands. -}
testStaleGeneration :: IO Property
testStaleGeneration = do
  store <- newForeignStore
  releases <- newReleases
  first <- claimOwnedGeneration store 4096 (releasing releases 4096)
  stale <- case first of
    Nothing -> pure 0
    Just generation -> do
      _ <- takeOwnedGeneration store 4096 generation
      pure generation
  second <- claimOwnedGeneration store 4096 (releasing releases 4096)
  let current = maybe 0 id second
  leased <- withOwnedGenerations store [(4096, stale)] (pure ())
  takenStale <- takeOwnedGeneration store 4096 stale
  leasedCurrent <- withOwnedGenerations store [(4096, current)] (pure ())
  takenCurrent <- takeOwnedGeneration store 4096 current
  pure
    ( conjoin
        [ counterexample "the reused address gets a new generation" (property (stale /= current))
        , counterexample "the stale generation cannot be leased" (leased === Nothing)
        , counterexample "the stale generation cannot be released" (property (isNothingResource takenStale))
        , counterexample "the occupant is still usable" (leasedCurrent === Just ())
        , counterexample "the occupant is still releasable" (property (isJustResource takenCurrent))
        ]
    )

{-| A conversion that fails after its batch was claimed discards exactly what it
    claimed. It cannot reach a newer resource that happens to sit at the same
    address, because that one belongs to a claim it never made. -}
testDiscardOwnClaims :: IO Property
testDiscardOwnClaims = do
  store <- newForeignStore
  releases <- newReleases
  claimed <- claimAllOwnedGenerations store [(4096, releasing releases 4096), (8192, releasing releases 8192)]
  let generations = either (const []) id claimed
  discardOwnedGenerations store generations
  afterDiscard <- released releases
  discardOwnedGenerations store generations
  afterRepeat <- released releases
  reused <- claimOwnedGeneration store 4096 (releasing releases 4096)
  discardOwnedGenerations store generations
  afterStale <- released releases
  occupant <- case reused of
    Nothing -> pure Nothing
    Just generation -> takeOwnedGeneration store 4096 generation
  pure
    ( conjoin
        [ counterexample "each claim is released once" (afterDiscard === [4096, 8192])
        , counterexample "discarding again releases nothing" (afterRepeat === [4096, 8192])
        , counterexample "a newer occupant is not reachable by the old claim" (afterStale === [4096, 8192])
        , counterexample "and it is still there" (property (isJustResource occupant))
        ]
    )

{-| Teardown closes admission first. A product that arrives after that has no
    owner to release it later, so it is released now rather than inserted
    behind a store nothing will drain again. -}
testClosedAdmission :: IO Property
testClosedAdmission = do
  store <- newForeignStore
  releases <- newReleases
  closeForeignStore store
  refusedOne <- claimOwnedGeneration store 4096 (releasing releases 4096)
  afterOne <- released releases
  refusedBatch <- claimAllOwnedGenerations store [(8192, releasing releases 8192)]
  leased <- withOwnedGenerations store [(4096, 1)] (pure ())
  pure
    ( conjoin
        [ counterexample "a late claim is refused" (refusedOne === Nothing)
        , counterexample "and its resource is released, not leaked" (afterOne === [4096])
        , counterexample "a late batch is refused" (property (isRefusal refusedBatch))
        , counterexample "a closed store leases nothing" (leased === Nothing)
        ]
    )

{-| A native call is interruptible while it runs, so an evaluation cancelled
    inside one lands there. The lease has to end anyway: an address still marked
    in use is one nothing can release, and teardown waits on it for as long as
    its patience lasts and then leaves it.

    Deterministic on purpose. The leaseholder blocks on an empty variable rather
    than on a sleep, so the exception arrives while the lease is certainly held,
    and the wait for the claim afterwards is bounded — release removes a claim
    only once no one is inside it, so a lease that was never given back would
    wait for ever rather than fail. -}
testInterruptedLease :: IO Property
testInterruptedLease = do
  store <- newForeignStore
  releases <- newReleases
  claimed <- claimOwnedGeneration store 4096 (releasing releases 4096)
  let generation = maybe 0 id claimed
  leased <- newEmptyMVar
  blocked <- newEmptyMVar
  leaseholder <- forkIO $ do
    _ <- withOwnedGenerations store [(4096, generation)] (putMVar leased () >> takeMVar blocked)
    pure ()
  takeMVar leased
  throwTo leaseholder ThreadKilled
  recovered <- timeout oneSecond (takeOwnedGeneration store 4096 generation)
  afterwards <- released releases
  pure
    ( conjoin
        [ counterexample "the claim comes back rather than staying in use"
            (property (maybe False isJustResource recovered))
        , counterexample "and cancelling a lease is not itself a release" (afterwards === [])
        ]
    )

oneSecond :: Int
oneSecond = 1000000

isRefusal :: Either [Int64] a -> Bool
isRefusal = either (const True) (const False)

refusedAddresses :: Either [Int64] a -> [Int64]
refusedAddresses = either sort (const [])

isJustGeneration :: Maybe Integer -> Bool
isJustGeneration = maybe False (const True)

isJustResource :: Maybe a -> Bool
isJustResource = maybe False (const True)

isNothingResource :: Maybe a -> Bool
isNothingResource = maybe True (const False)
