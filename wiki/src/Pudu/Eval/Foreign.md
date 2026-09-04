---
type: module
path: "@root/src/Pudu/Eval/Foreign.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.7
tags: [module, medium, runtime, foreign, ffi]
aliases: [Eval Foreign]
---

# Eval Foreign

## Purpose

Make the call a foreign declaration describes, enforcing everything it promised on the way through.

## Interface

```haskell
callForeign :: Span -> ForeignBinding -> [Value] -> Evaluator Value
```

### Governance

- **Every check that can happen before the call happens before the call.** Past this point the value
  is in somebody else's hands and a mistake stops being a diagnostic and becomes a corrupted stack.
- **An integer that does not fit its declared width is refused rather than wrapped.** A value that
  does not fit would arrive as a different value and the program would continue with it.
- **A returned integer is interpreted with the declared signedness.** The native carrier is a
  64-bit bit pattern, so `UInt64` values above `Int64` maximum are widened as unsigned before a Pudu
  integer is built. The same rule applies to fields in a returned record.
- **Text carrying a nought is refused.** The other side reads to the first nought, so it would see
  less than the text says — and text shortened without anybody being told is how a check on the
  whole of it is passed by only part of it.
- **Everything one call produced is claimed together.** A call may hand back a result and the
  resources it wrote into slots; claiming some and failing on the rest would leave the program owning
  things it cannot name, so one store transaction decides for all of them and the tuple is exposed
  only after it succeeds.
- **A slot leases nothing on the way in.** A handle a caller passes is leased for the call; a handle
  a slot receives did not exist before the call and is claimed after it.
- **A foreign call is an effect**, so a compile-time constant cannot make one. What a program
  compiles to must not depend on what happened to be installed on the machine that compiled it.
- **A failure names the library and the symbol**, because the usual cause is that the library is not
  installed and the usual remedy is to install it.
- **A handle is opaque and nominal.** Only a runtime handle bearing the crossing's declared name may
  pass, and its address is never exposed as an integer.
- **Ownership covers the complete native call.** Null owned results are refused; ordinary handle
  uses acquire atomic leases held until native code returns; release waits for leases and removes
  the claim before calling the destructor. A call-setup failure restores a release claim because the
  destructor did not run. A producer records the declared native release action for runtime cleanup.

### Linkage

- **Requires:** [[Eval Env]], [[Eval Value]], [[Foreign Call]], [[Foreign Crossing]].
- **Used by:** [[Eval Call]].

## Grill Log

- **Q:** Wrap an out-of-range integer to the declared width, as C does? **A:** No.
  _Rationale:_ the caller computed a number and would get a different one, with
  nothing said. That is the oldest way for a program calling a library to keep
  running on a value it never produced. _Rejected:_ wrapping; clamping.
- **Q:** Strip the nought from text rather than refusing it? **A:** No.
  _Rationale:_ stripping hands the other side a shorter string while the caller
  believes the whole of it crossed — and whatever was checked about the whole was
  not checked about the part. _Rejected:_ truncating at the nought.
- **Q:** Let a release function decide whether a handle is valid? **A:** No. _Rationale:_ calling a
  destructor twice is already undefined behaviour; validation after the call is too late.
  _Rejected:_ foreign-side double-release detection as the safety boundary.
- **Q:** Check liveness and then call after dropping the ownership lock? **A:** No. _Rationale:_ a
  concurrent release could free the address in that gap. _Rejected:_ membership checks without a
  lease spanning the call.
- **Q:** Turn invalid returned UTF-8 into replacement characters? **A:** No. _Rationale:_ replacement
  silently changes data at the least trustworthy boundary. _Rejected:_ lossy decoding; host
  exceptions escaping the evaluator.


## Rejected output batches

A failed claim never destroys an address already held by the store. Fresh outputs are grouped by
address and cleaned once only when all occurrences agree on canonical handle type, release library,
and release symbol. Conflicting obligations are left unfreed rather than invoking an arbitrary
destructor. Duplicate products are rejected even when their obligations agree.

### Resolved Grill

- **Q:** Release every output after a batch refusal? **A:** No. Preserve protected addresses and
  group fresh candidates by their complete release obligation before cleanup. A failed claim does
  not transfer ownership of an already-held address to its caller.

## Conversion-failure cleanup

Post-call failures retain produced handle addresses. The evaluator resolves their release obligations
from the binding and settles the batch before reporting the original conversion diagnostic. Existing
claims are protected and ambiguous obligations remain unfreed. Fresh, unambiguous resources are
released once, including resources produced beside invalid UTF-8.

### Resolved Grill

- **Q:** Wait for a successful text conversion to discover ownership? **A:** No; the native bridge
  retains raw handle outputs even when conversion fails.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
