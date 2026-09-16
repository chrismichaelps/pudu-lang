{-| @Test.Compiler.Program.ForeignSpec — C++ FFI handle crossing, memory leases, and foreign store concurrency -}
module Pudu.Compiler.Program.ForeignSpec
  ( cppActiveCount
  , cppDeleteCount
  , cppFixtureAnchor
  , foreignProperties
  , testForeignHandles
  , testForeignOwnershipStore
  , testForeignTeardownEnds
  ) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar, threadDelay, tryTakeMVar)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Maybe (isJust, isNothing)
import qualified Data.Text as Text
import Foreign.C.Types (CInt (..))
import Pudu.Compiler.Program.Common (codes, runEntry, runtimeCodes, runtimeMessages)
import Pudu.Foreign.Ownership
  ( claimOwned
  , closeForeignStore
  , newForeignStore
  , restoreOwned
  , takeOwned
  , withOwned
  )
import System.Timeout (timeout)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

foreignProperties :: [(String, IO Property)]
foreignProperties =
  [ ("opaque handles cross a real C++ boundary with one release", testForeignHandles)
  , ("foreign ownership serializes release and call use", testForeignOwnershipStore)
  , ("foreign teardown ends even while a native call is inside", testForeignTeardownEnds)
  ]

foreign import ccall unsafe "pudu_ffi_cpp_anchor"
  cppFixtureAnchor :: IO CInt

foreign import ccall unsafe "pudu_ffi_cpp_delete_count"
  cppDeleteCount :: IO CInt

foreign import ccall unsafe "pudu_ffi_cpp_active_count"
  cppActiveCount :: IO CInt

testForeignHandles :: IO Property
testForeignHandles = do
  CInt anchor <- cppFixtureAnchor
  successful <- runEntry "test-fixtures/stdlib/UsesForeignHandles.pudu"
  imported <- runEntry "test-fixtures/foreignmodule/Main.pudu"
  records <- runEntry "test-fixtures/stdlib/UsesForeignRecords.pudu"
  nested <- runEntry "test-fixtures/stdlib/UsesForeignNested.pudu"
  text <- runEntry "test-fixtures/stdlib/UsesForeignText.pudu"
  crossings <- runEntry "test-fixtures/stdlib/UsesForeignCrossings.pudu"
  slots <- runEntry "test-fixtures/stdlib/UsesForeignSlots.pudu"
  bytes <- runEntry "test-fixtures/stdlib/UsesForeignBytes.pudu"
  noText <- runtimeCodes "test-fixtures/stdlib/RejectsForeignTextNone.pudu"
  invalidText <- runtimeCodes "test-fixtures/stdlib/RejectsForeignInvalidUtf8.pudu"
  missingRecordText <- runtimeCodes "test-fixtures/stdlib/RejectsForeignRecordNoText.pudu"
  crossingShapes <- codes "test-fixtures/stdlib/RejectsForeignCrossingShapes.pudu"
  refusedRecords <- codes "test-fixtures/foreignrecords/Main.pudu"
  beforeDouble <- cppDeleteCount
  doubleRelease <- runtimeCodes "test-fixtures/stdlib/RejectsForeignDoubleRelease.pudu"
  afterDouble <- cppDeleteCount
  useAfterRelease <- runtimeCodes "test-fixtures/stdlib/RejectsForeignUseAfterRelease.pudu"
  nullResult <- runtimeCodes "test-fixtures/stdlib/RejectsForeignNullHandle.pudu"
  duplicateOwnership <- runtimeCodes "test-fixtures/stdlib/RejectsDuplicateForeignOwnership.pudu"
  borrowed <- codes "test-fixtures/stdlib/RejectsBorrowedForeignHandle.pudu"
  borrowedRelease <- codes "test-fixtures/stdlib/RejectsBorrowedForeignRelease.pudu"
  countedNoRelease <- codes "test-fixtures/stdlib/RejectsCountedForeignNoRelease.pudu"
  countedHandle <- runEntry "test-fixtures/stdlib/UsesCountedForeignHandle.pudu"
  beforeBorrowed <- cppDeleteCount
  borrowedHandle <- runEntry "test-fixtures/stdlib/UsesBorrowedForeignHandle.pudu"
  releasingBorrowed <- runtimeCodes "test-fixtures/stdlib/RejectsReleasingBorrowedHandle.pudu"
  afterBorrowed <- cppDeleteCount
  badRelease <- codes "test-fixtures/stdlib/RejectsForeignReleaseShape.pudu"
  bytesSlot <- codes "test-fixtures/stdlib/RejectsForeignBytesSlot.pudu"
  wrongHandle <- codes "test-fixtures/stdlib/RejectsForeignWrongHandle.pudu"
  emptySymbol <- codes "test-fixtures/stdlib/RejectsEmptyForeignSymbol.pudu"
  qualifiedHandle <- codes "test-fixtures/foreignqualified/Root.pudu"
  importedCapability <- codes "test-fixtures/importedcapability/Main.pudu"
  typeMembers <- codes "test-fixtures/typemember/Main.pudu"
  carriedCapability <- runEntry "test-fixtures/capabilitytype/Main.pudu"
  escapedCapability <- codes "test-fixtures/capabilityescape/Main.pudu"
  higherComptime <- runEntry "test-fixtures/comptimehigher/Main.pudu"
  beforeCleanup <- cppDeleteCount
  CInt activeBefore <- cppActiveCount
  cleanupSuccess <- runEntry "test-fixtures/stdlib/UsesForeignHandleCleanup.pudu"
  cleanupReturn <- runEntry "test-fixtures/stdlib/UsesForeignHandleEarlyReturn.pudu"
  cleanupFailure <- runtimeCodes "test-fixtures/stdlib/RejectsAfterForeignHandleCleanup.pudu"
  afterCleanup <- cppDeleteCount
  CInt activeAfter <- cppActiveCount
  beforeSlotText <- cppDeleteCount
  CInt activeBeforeSlotText <- cppActiveCount
  invalidTextWithSlot <- runtimeCodes "test-fixtures/stdlib/RejectsForeignInvalidUtf8WithSlot.pudu"
  unaliasedImport <- runEntry "test-fixtures/stdlib/UsesUnaliasedImport.pudu"
  missingVersioned <- runtimeMessages "test-fixtures/stdlib/RejectsMissingForeignLibraryVersion.pudu"
  afterSlotText <- cppDeleteCount
  CInt activeAfterSlotText <- cppActiveCount
  pure $ conjoin
    [ counterexample "the C++ fixture is linked into the running process" (anchor === 1)
    , counterexample "a run of bytes is lent whole, noughts and emptiness included"
        (bytes === Just "6")
    , counterexample "a library writes scalars, text, records and resources through slots"
        (slots === Just "17")
    , counterexample "a C++ object crosses as an opaque handle and is read and released"
        (successful === Just "2")
    {-| A record crossing by value, which is how nearly every library worth
        calling passes a colour, a point, or a rectangle. Four bytes packed into
        a register on the way out and read back field by field; a record of two
        classes with padding between them, both directions; and fields written
        in an order the declaration did not use, which still cross in the order
        it did. Where a field sits inside a record is asked of the platform
        rather than calculated here, because a calculation would be right on the
        machine it was written for. -}
    , counterexample "a record crosses a foreign boundary by value"
        (records === Just "12")
    {-| What a record still cannot do. Nesting is admitted, because a record is
        described by the leaves it flattens to. A record reached from inside
        itself has no flattening — there is no end to its leaves — and a field
        whose own type cannot cross takes the record with it. Both are refused
        at the declaration, where a reader can see why, rather than at a call
        where the answer would be a fault. -}
    , counterexample "a circular record and an uncrossable field are refused where they are written"
        (refusedRecords === ["E3063", "E3063"])
    {-| Text a library hands back arrives as text. It used to arrive as the
        address it crossed as, while the checker had already called it a Str —
        so a program printed a number where it had asked for a string, and
        nothing said otherwise. It is copied at the boundary, which ends every
        question about whose storage it was. -}
    , counterexample "text a library returns arrives as text, not as its address"
        (text === Just "5")
    , counterexample "no text where text was declared is refused rather than read through"
        (noText === ["E7024"])
    , counterexample "every admitted scalar and flat-record crossing round-trips exactly"
        (crossings === Just "20")
    , counterexample "invalid returned UTF-8 is a runtime refusal"
        (invalidText === ["E7025"])
    {-| Text that cannot be decoded does not cancel a release. The library
        wrote a resource through the slot before the boundary ever looked at
        the text, and the address it wrote never reaches the program, so a
        boundary that reports the decoding failure and walks away is the one
        arrangement in which nothing can free it. -}
    , counterexample "a resource produced beside invalid text is still refused as text"
        (invalidTextWithSlot === ["E7025"])
    , counterexample "and released, rather than left with nothing able to name it"
        (afterSlotText - beforeSlotText === 1)
    , counterexample "leaving no live box behind"
        (activeAfterSlotText === activeBeforeSlotText)
    {-| An import without `as` is reached through the module's own last segment.
        The checker resolved names against that segment while the evaluator
        bound nothing unless an alias was written, so a program using the
        documented form checked clean and then failed at run time with an
        undefined name. Both sides ask one function for the qualifier now. -}
    , counterexample "an unaliased import binds the qualifier the checker resolved against"
        (unaliasedImport === Just "5")
    {-| A declared version reaches the loader. The platform writes a version
        inside the library's file name, and the unversioned spelling is usually
        a symlink shipped for building against — so a machine holding the
        library and not its headers has only the versioned one. The refusal
        names what it asked for, which is where this is visible. -}
    , counterexample "a declared version is asked for in each platform's spelling"
        ( property
            ( any
                (\said -> all (`Text.isInfixOf` said)
                  ["libnosuchlibrary.so.9", "libnosuchlibrary.9.dylib", "libnosuchlibrary-9.dll"])
                missingVersioned
            )
        )
    , counterexample "a null text field in a returned record is refused"
        (missingRecordText === ["E7024"])
    , counterexample "invalid shapes are precise while exact bridge capacities remain admitted"
        (crossingShapes === ["E3070", "E3071", "E3069", "E3063", "E3063", "E3063"])
    {-| A record inside a record. A camera holds two points and a font holds a
        texture, so a boundary admitting only flat records admits almost none of
        what a library passes about. What crosses is the leaves, in declaration
        order, which is the same description the platform derives for the
        nesting itself — proved against a C++ surface before anything was built
        on it, including a record whose nesting sits between fields that need
        padding around it. -}
    , counterexample "a record inside a record crosses by value"
        (nested === Just "8")
    , counterexample "an exported binding module keeps canonical handle types and runtime symbols"
        (imported === Just "1")
    , counterexample "a second release is refused before C++ is entered"
        (doubleRelease === ["E7022"])
    , counterexample "the native destructor ran exactly once"
        (afterDouble - beforeDouble === 1)
    , counterexample "an alias cannot use a handle after release"
        (useAfterRelease === ["E7022"])
    , counterexample "a null owned result is refused"
        (nullResult === ["E7020"])
    , counterexample "one live native address cannot create two ownership claims"
        (duplicateOwnership === ["E7021"])
    {-| A library hands back two different things through one C type: what it
        gives away, and what it keeps — a default font, the text of a last
        error, the surface a context draws to. Saying neither is refused,
        because the address does not say which and guessing either way is a
        leak or a free of something still in use. -}
    , counterexample "a handle result saying neither owned nor borrowed is refused"
        (borrowed === ["E3066"])
    , counterexample "a borrowed result naming a release is refused"
        (borrowedRelease === ["E3074"])
    , counterexample "a counted result naming no release is refused"
        (countedNoRelease === ["E3075"])
    {-| Taking a reference returns the pointer the last one returned, so two
        references are one address. Each still owes its own drop: a boundary
        that mistook them for one claim would leave the library's count above
        zero for ever, and one that released the address once would drop a
        reference the program still holds. -}
    , counterexample "two references to one address are two claims that drop separately"
        (countedHandle === Just "6")
    , counterexample "a borrowed handle is read like any other"
        (borrowedHandle === Just "3")
    {-| The only spelling available before this was `owned ... by`, which made
        the boundary release the library's own object at teardown. Refusing the
        declaration did not prevent that; it required it. -}
    , counterexample "and releasing one is refused rather than freeing what the library kept"
        (releasingBorrowed === ["E7022"])
    , counterexample "so nothing was destroyed across either program"
        (afterBorrowed - beforeBorrowed === 0)
    {-| A release answering a number is admitted, because in C that is what
        releasing looks like — `sqlite3_close` and `fclose` both answer one —
        and refusing it meant no such library could be bound without a shim
        whose only work was to discard the number. What that costs is that a
        reader answering a number can be named as a release and the shapes
        cannot be told apart; C offers nothing that would tell them apart, and
        the value is discarded either way. A release answering a handle stays
        refused, since that is the library returning a resource nobody claims. -}
    , counterexample "a release must take its matching handle and hand nothing back"
        (badRelease === ["E3067", "E3066"])
    {-| The direction a run of bytes crosses is the whole of its contract:
        lent, read-only, for the length of the call. A slot is the other
        direction, so admitting one would let a library write into storage the
        language holds as unchanging — and nothing downstream would notice,
        which is what makes it worth a refusal rather than a caveat. -}
    , counterexample "a run of bytes cannot be a slot the library writes into"
        (bytesSlot === ["E3074"])
    , counterexample "nominal handles cannot cross as another declared handle"
        (wrongHandle === ["E3001"])
    , counterexample "an empty native symbol is refused at its declaration"
        (emptySymbol === ["E3068"])
    , counterexample "a qualified same-basename type is not a block-local handle"
        (qualifiedHandle === ["E3063"])
    , counterexample "a capability travels with the function value"
        (carriedCapability === Just "1")
    , counterexample "a requirement cannot be lost by storing or passing the function"
        (escapedCapability === ["E3023", "E3001", "E3023"])
    , counterexample "a compile-time function may call the function it was given"
        (higherComptime === Just "3")
    , counterexample "a member a type does not have is refused where it is written"
        (typeMembers === ["E3034", "E3034", "E3034", "E3034"])
    , counterexample "an imported declaration keeps the restrictions it was declared under"
        (importedCapability === ["E3023", "E3023", "E3023", "E3023", "E3023", "E3025"])
    , counterexample "runtime teardown preserves a successful result"
        (cleanupSuccess === Just "1")
    , counterexample "runtime teardown preserves an early-return result"
        (cleanupReturn === Just "1")
    , counterexample "runtime teardown also follows an aborted evaluation"
        (cleanupFailure === ["E7007"])
    , counterexample "all three abandoned resources run their declared destructor"
        (afterCleanup - beforeCleanup === 3)
    , counterexample "no native object remains live after any evaluator exit"
        (activeAfter === activeBefore)
    ]

{-| Teardown ends, and leaves alone what somebody is inside.

    An unbounded wait here was a program that hangs on exit with nothing said
    whenever a foreign call does not return — the one failure that hides every
    other. The resource still leased keeps its claim and its destructor is not
    called, because freeing an address another thread is holding is the fault
    this store exists to prevent. -}
testForeignTeardownEnds :: IO Property
testForeignTeardownEnds = do
  store <- newForeignStore
  idleCleanups <- newIORef (0 :: Int)
  leasedCleanups <- newIORef (0 :: Int)
  _ <- claimOwned store 11 (modifyIORef' idleCleanups (+ 1))
  _ <- claimOwned store 22 (modifyIORef' leasedCleanups (+ 1))
  entered <- newEmptyMVar
  finishUse <- newEmptyMVar
  _ <- forkIO $ do
    _ <- withOwned store [22] (putMVar entered () >> takeMVar finishUse)
    pure ()
  takeMVar entered
  ended <- timeout 20000000 (closeForeignStore store)
  idle <- readIORef idleCleanups
  leased <- readIORef leasedCleanups
  putMVar finishUse ()
  pure $ conjoin
    [ counterexample "teardown ends rather than waiting for a call that is still inside"
        (property (isJust ended))
    , counterexample "a resource nobody is inside runs its declared destructor"
        (idle === 1)
    , counterexample "a resource somebody is inside is left alone rather than freed under them"
        (leased === 0)
    ]

testForeignOwnershipStore :: IO Property
testForeignOwnershipStore = do
  store <- newForeignStore
  cleanupCount <- newIORef (0 :: Int)
  claimed <- claimOwned store 77 (modifyIORef' cleanupCount (+ 1))
  entered <- newEmptyMVar
  finishUse <- newEmptyMVar
  useFinished <- newEmptyMVar
  _ <- forkIO $ do
    result <- withOwned store [77] (putMVar entered () >> takeMVar finishUse)
    putMVar useFinished (isJust result)
  takeMVar entered
  releaseStarted <- newEmptyMVar
  releaseResult <- newEmptyMVar
  _ <- forkIO $ do
    putMVar releaseStarted ()
    takeOwned store 77 >>= putMVar releaseResult
  takeMVar releaseStarted
  threadDelay 10000
  premature <- tryTakeMVar releaseResult
  putMVar finishUse ()
  leaseCompleted <- takeMVar useFinished
  released <- takeMVar releaseResult
  case released of
    Nothing -> pure ()
    Just resource -> restoreOwned store 77 resource
  closeForeignStore store
  cleaned <- readIORef cleanupCount
  pure $ conjoin
    [ counterexample "the address is claimed once" (claimed === True)
    , counterexample "release waits while native use holds a lease" (property (isNothing premature))
    , counterexample "the native use completes before release takes ownership" (leaseCompleted === True)
    , counterexample "release receives the resource after the lease closes" (property (isJust released))
    , counterexample "teardown invokes the restored cleanup once" (cleaned === 1)
    ]
