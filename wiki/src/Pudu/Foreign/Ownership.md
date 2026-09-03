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
  process is ending, so the memory returns anyway — an abandoned resource costs
  nothing and a destructor called under a live user costs everything.
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

## Referenced by

[[src/Pudu/Foreign/_MOC]] · [[Evaluator]] · [[ADR-0018 Calling a Library Written Elsewhere]]
