---
type: handoff
status: ACTIVE
issue: 877
aliases: [Foreign Pointer Delivery]
---

# Foreign Pointer Delivery

Language Architect → Backend, Semantic and Runtime Engineers after review of
[[Foreign Pointers and Runs]]. The first implementation owns non-null foreign
loans to one scalar or record, including writeback through an ordinary mutable
place. Later partitions own arrays, bounds, nullable and returned values, and
function pointers.

## Resolved Grill Log

- A loan expires at return from the foreign call. The bridge copies in and
  writes back the final mutable values using existing Pudu place rules.
- The target ABI supplies record layout. Interpreter and native evidence
  includes nested records with padding as well as scalar widths.
- One length checks every named run. Returned runs copy initialized elements
  before releasing the transferred allocation, including on conversion failure.
- Success, overlapping loans, forbidden pointees and forbidden results need
  focused checks in both execution paths. Array capacity, null and lifetime
  cases belong to the partitions that introduce those crossings.

## Scalar and record implementation

Runtime Engineer → Semantic Engineer → Backend Engineer. This partition
owns declaration admission, pointee snapshots and writeback for non-null
scalar and record loans. The interpreter uses the existing libffi slot
layout and the native emitter gives the library pointers to ABI locals.
The interpreter and native backend preserve mutable snapshots across
post-call failures. Native failure capture arms after C returns and replays
the report after the caller stores the loan finals. Validation is pending.

## Run syntax and storage

Backend Engineer → Frontend Engineer → Runtime Engineer. The parser retains
located extent relations, result length-slot names and nullable modifiers.
The checked bounds and their target order reach both byte-buffer paths.
[[Foreign Run Storage]] queries libffi for element stride and offsets and
owns the aligned interpreter buffer. Nullable inputs remain pending.

## Typed array input crossings

Runtime Engineer → Backend Engineer. Both execution paths check array
bounds before dispatch and use the target ABI stride. Mutations re-enter
Pudu through the existing loan destination. A present empty array gets
a non-null address, independent of its element count. Validation is pending.

## Optional opaque handles

Backend Engineer → Semantic Engineer → Runtime Engineer → Backend Engineer.
Optional handles use the same ABI pointer as required handles. The
interpreter leases a present handle's generation. Generated C pins that
generation while a callback-bearing call yields the run gate. Results
retain their owned, borrowed, or counted policy, and failed conversion
discharges produced claims. Validation is pending.

## Returned allocations

Backend Engineer → Semantic Engineer → Runtime Engineer → Backend Engineer.
Returned arrays resolve their output length and release at declaration
checking. The interpreter and emitted C claim the pointer before decoding,
copy the initialized elements, and discharge the allocation. Optional null
is admitted only at length zero. Validation is pending.

## Nullable references

Backend Engineer → Semantic Engineer → Runtime Engineer → Backend Engineer.
The checker contextualizes bare None at declared nullable parameter
positions. The interpreter and C11 carry a null address and zero extent
with no copy-out destination. A present referent uses the existing copy-in
and copy-out path. Validation is pending.

## Split callbacks and byte runs

Frontend Engineer → Semantic Engineer → Runtime Engineer → Backend Engineer.
Split declarations distinguish a hidden trampoline position and an explicit
registration context. The interpreter reuses adapters within a run. Emitted
C yields the gate around calls in a split callback block so a later call can
invoke the retained registration. Both paths decode a callback byte run from
a checked integer length and copy it before entering the handler. Scalar and
small record callbacks use stack storage for the libffi argument carriers.
Validation is pending.

## Callback groups

Frontend Engineer → Semantic Engineer → Backend Engineer → Runtime Engineer.
Group declarations resolve earlier callback signatures in field order. The
constructor checks a handler record by name. Lowering resolves the concrete
record offsets and the C11 registration retains that record under one key.
The interpreter registry retains the same record and routes each libffi
adapter's checked ordinal through that key. Unregister retires the whole
group. Validation is pending.

## Portable loading and close

Runtime Engineer → Backend Engineer → Tooling Engineer. The interpreter,
generated C11 and SQLite use one platform loader. Independently owned handles
close admission and wait for scoped uses. Declaration symbols retain their
process-owned module because callbacks and native objects can outlive the call.
Generated wrappers use an atomic cached-symbol read after first resolution.
SQLite releases its loader reference when its last dependent object drops.
Validation is pending.

## Objective-C dispatch

Frontend Engineer → Semantic Engineer → Runtime Engineer → Backend Engineer.
Class aliases enter the block's opaque type scope. A class send names its
receiver, and an instance send takes the first class handle as its receiver.
Both dispatch paths insert the selector at the ABI boundary and retain source
indexes for output slots and loans. The native wrapper casts to the complete
fixed signature. The interpreter gives that signature to libffi. Dispatch
selects the Intel structure-return entry where needed. Validation is pending.

## Core C ABI conformance cases

Backend Engineer → Testing Engineer. The existing interpreter/native
conformance harness now has explicit expected outputs for nullable and
mutable runs, an owned allocation released exactly once, split and shared
callback contexts, and copied callback bytes. The fixtures are written
and await the validation pass.

## Compiler integration

The macOS GHC 9.14.1 build produced the compiler executable and the test
harness. The foreign syntax participates in literal rewriting, source
provenance and cache persistence. The conformance suite has yet to run.

## Initializer transfer and first conformance run

The interpreter marks an initializer receiver unavailable during transfer,
restoring its claim only for a pre-entry ABI failure. Generated C checks
that the receiver is idle, rejects aliases of its claim among the other
arguments, and consumes that claim immediately before dispatch.

On macOS with GHC 9.14.1 the five native foreign regression groups pass,
including 15 allocation-counted programs, ordinary call success and refusal,
callbacks, and the four new explicit-output crossing cases. The run caught
and corrected normalized None admission, fixture binding syntax and loader
metadata cleanup. Full-suite and Apple-specific conformance remain pending.

## Autorelease pools and blocks

Foreign teardown now releases unreleased claims newest first, by claim
generation, in both the interpreter and generated C, so scope-shaped
resources close inside out. An Objective-C autorelease pool is an ordinary
owned handle declared through `objc_autoreleasePoolPush` and
`objc_autoreleasePoolPop`, with no new syntax. A callback parameter written
`block Work` crosses as a stack block whose last field is the registration
key; a callee that keeps it copies the block, and the copy carries the key.
The callback must take its context first, or the checker refuses with E3063.
Both Objective-C conformance groups and all 17 foreign groups pass on macOS.

## Exact next action

Add delegate objects for Objective-C protocols under #879 (runtime-created
classes whose methods are callback trampolines), then run the Foundation and
block conformance on the iOS simulator.

## Referenced by

[[handoffs/_MOC]] · [[Foreign Pointers and Runs]]
