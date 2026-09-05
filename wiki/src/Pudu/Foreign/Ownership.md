---
type: module
path: "@root/src/Pudu/Foreign/Ownership.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.68
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.7
tags: [module, medium, foreign, ffi, ownership]
aliases: [Foreign Ownership]
---

# Foreign Ownership

## Purpose

Own one evaluation's foreign-resource claims, coordinate concurrent uses with release, and run
declared native cleanup for resources still live when the evaluation ends.

## Interface

```haskell
data ForeignStore
data ForeignResource

newForeignStore   :: IO ForeignStore
closeForeignStore :: ForeignStore -> IO ()
claimOwned        :: ForeignStore -> Int64 -> IO () -> IO Bool
claimAllOwned     :: ForeignStore -> [(Int64, IO ())] -> IO (Either [Int64] ())
withOwned         :: ForeignStore -> [Int64] -> IO a -> IO (Maybe a)
takeOwned         :: ForeignStore -> Int64 -> IO (Maybe ForeignResource)
restoreOwned      :: ForeignStore -> Int64 -> ForeignResource -> IO ()
```

### Governance

- One store belongs to one evaluator run and is shared by every captured closure and child thread
  of that run. Independent evaluations cannot invalidate one another's handles.
- A normal foreign call atomically leases every distinct handle before entering native code and
  releases the leases afterward on success or host failure. A release waits for all active leases,
  then atomically removes the claim before calling the destructor.
- Each claim retains a best-effort cleanup action assembled from the producer's declared library and
  release symbol. Runtime teardown waits for leases, removes every remaining claim, and invokes each
  cleanup exactly once.
- The store never exposes an address to Pudu code and never invents a release action from naming
  convention.

### Linkage

- **Requires:** [[Foreign Call]], [[Eval Foreign]].
- **Used by:** [[Eval Env]], [[Evaluator]].

## Closing and cancellation

The store has a permanent closing state. Closing rejects new leases and claims; products arriving
after closing are cleaned instead of being inserted behind teardown. Busy resources remain claimed
until their final lease ends, which removes and cleans them when the store is closing. Teardown
still waits at most five seconds, but returning after that deadline no longer abandons resources
whose native calls eventually return. A native call that never returns still prevents safe release.

Lease acquisition and installation of its cleanup handler are masked against asynchronous
exceptions. The native action uses the caller's prior masking state. Draining and cleanup handoff
are masked as well. Restoration never overwrites another claim; restoring into a closed empty slot
runs its cleanup instead of reopening the store.

### Resolved Grill

- **Q:** Assume evaluator teardown means process termination? **A:** No. Embedded and REPL runs
  can outlive an evaluation; the final native lease performs deferred cleanup after closing.
- **Q:** Install `finally` after an unmasked acquisition? **A:** No; mask across acquisition and
  handler installation, then restore the incoming masking state for the action.

## Algorithm

An STM table maps addresses to live resources and active lease counts. Multi-handle acquisition is
one transaction; release retries while a live lease exists; teardown atomically drains only after
all leases reach zero, then performs cleanup outside STM.

## Negative Logic (Prohibited Paths)

- No process-global ownership table, check-then-call gap, destructor call inside STM, address reuse
  while a claim is live, or cleanup inferred from a local function spelling.

## Edge Cases

- Repeated addresses in one call acquire one lease. A missing or already-releasing address refuses
  the whole acquisition without partially leasing the others.
- Cleanup failures during teardown are contained because no Pudu continuation remains to receive a
  recoverable result; explicit release failures still surface through the ordinary foreign call.

## Grill Log

- **Q:** Wait as long as it takes for every lease to close at teardown? **A:** No;
  wait a bounded five seconds and then stop. _Rationale:_ teardown has to end. An
  unbounded wait is a program that hangs on exit with nothing said whenever a
  foreign call does not return, which is the one failure that hides every other.
  _Rejected:_ an unbounded `retry`.
- **Q:** Free what is still leased when the wait ends? **A:** No; leave it.
  _Rationale:_ another thread is inside the library holding that address, and
  freeing underneath it is the exact fault this store exists to prevent. The
  final lease now owns deferred cleanup; an embedded evaluation need not terminate its process.
  _Rejected:_ freeing regardless; refusing to exit.
- **Q:** Bound the wait with `System.Timeout.timeout`? **A:** No; a deadline in
  STM. _Rationale:_ `timeout` bounds a computation by throwing to the thread
  running it, which makes the guarantee depend on an asynchronous exception
  reaching a thread parked in `retry`. `registerDelay` with `orElse` is the same
  bound expressed as a transaction, and it either drains or takes what is idle
  without leaving the question of delivery open. _Rejected:_ an asynchronous
  bound around a blocking transaction.

- **Q:** Report a handle live and call native code after releasing the lock? **A:** No; lease it for
  the complete call interval. _Rationale:_ another thread could destroy it between the check and
  dereference. _Rejected:_ an atomic membership test with an unprotected call.
- **Q:** Require every program path to call the destructor explicitly? **A:** No; retain explicit
  early release but clean remaining claims at runtime exit. _Rationale:_ returns and runtime failures
  must not leak native resources. _Rejected:_ comments or convention as cleanup proof.


## Batch-claim failure contract

`claimAllOwned :: ForeignStore -> [(Int64, IO ())] -> IO (Either [Int64] ())`
claims the complete batch only when all addresses are distinct and absent. `Left` contains
only addresses already protected by the store; it may be empty when the batch repeats a fresh
address. A failed batch inserts nothing. Cleanup actions are not comparable ownership identities.

### Resolved Grill

- **Q:** Coalesce duplicate products silently? **A:** No; refuse the complete batch. The caller
  has the canonical type and destructor metadata needed to decide which fresh products can be
  cleaned safely. Existing claims never become cleanup candidates.

## Cleanup diagnostics

`recordForeignDiagnostic` and `takeForeignDiagnostics` own a per-run diagnostic journal independent
of the resource map. Diagnostics are drained in recording order. They survive store closing so
teardown failures can be included in the evaluation outcome.

### Resolved Grill

- **Q:** Keep cleanup reporting process-global? **A:** No; failures belong to the evaluation whose
  resources caused them, including a failed result conversion and runtime teardown.

## Claim generations

Every accepted resource receives a monotonically increasing, unbounded integer generation in the
same STM transaction as insertion. `claimOwnedGeneration` and `claimAllOwnedGenerations` return
these generations. `withOwnedGenerations` and `takeOwnedGeneration` require address and generation
to match atomically. Address-only helpers remain for internal cleanup and existing host consumers;
Pudu values always use generation-aware admission. Restoration retains the original generation.

### Resolved Grill

- **Q:** Is an address enough to validate an old handle? **A:** No; allocators reuse addresses.
  A generation mismatch refuses use and release even while a new resource occupies that address.
- **Q:** Let a fixed-width generation counter wrap? **A:** No; the bootstrap uses an unbounded
  integer. A future native counter must refuse exhaustion before reusing an identity.

## Aborted result settlement

`discardOwnedGenerations` removes and cleans only the generations claimed by a failed result
conversion. It cannot destroy a newer occupant of the address. Removal and cleanup handoff are
masked; registered cleanup actions retain their warning journal.

### Resolved Grill

- **Q:** Leave a failed result's accepted resources until evaluation teardown? **A:** No; discard
  that transaction's exact generations when conversion aborts, before returning its primary error.

## Referenced by

[[src/Pudu/Foreign/_MOC]] · [[Evaluator]] · [[ADR-0018 Calling a Library Written Elsewhere]]
