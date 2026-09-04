---
type: module
path: "@root/src/Pudu/Foreign/Call.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: DEEP
coupling: 2.0
interface_stability: 0.6
tags: [module, deep, foreign, ffi, unsafe]
aliases: [Foreign Call]
---

# Foreign Call

## Purpose

Open a library the platform already has, find a function in it, and call through a signature
assembled while the program runs.

## Interface

```haskell
resolveSymbol :: Text -> Text -> IO (Either Text (Ptr ()))

data ForeignHandle
data CrossedValue = CrossedInteger !Int64 | CrossedDouble !Double | CrossedText !Text
                  | CrossedHandle !Text !Int64

openLibrary :: Text -> IO (Either Text ForeignHandle)
findSymbol  :: ForeignHandle -> Text -> IO (Either Text (Ptr ()))
callSymbol  :: Ptr () -> [(Crossing, CrossedValue)] -> Crossing -> IO (Either Text CrossedValue)
kindCode    :: Crossing -> Word8
```

### Governance

- **A library is named, never pathed.** A path in source is a claim about somebody else's machine.
  What this tries is the naming convention of the platform it is running on, and a failure says
  which names were tried, because the usual cause is that the library is not installed.
- **`"c"` asks the running program for its own symbols.** Every platform links the C library and
  every platform files it under a different name — and in one common case under a linker script
  rather than a library. A binding that hardcodes one of those names works on one machine, which is
  why nearly every language's C bindings carry a table of them.
- **A resolved symbol is kept, and the read is lock-free.** A call used to ask the dynamic linker
  for its function every time it ran — a hash lookup through the linker's tables plus a fresh
  nought-terminated copy of the name to hand it. An address does not change for the life of the
  process, so it is remembered. Measured over two hundred thousand calls, the boundary cost fell
  from 1.7µs to 0.25µs a call. Two threads racing to resolve the same symbol both call the linker
  and both write the same address, which costs one redundant lookup and no correctness; a lock to
  prevent that would sit on the hot path to save work that is already rare.
- **Text a library returns is copied out of its storage.** What crosses is an address, and the bytes
  behind it belong to whoever returned them — a static table, a buffer reused on the next call, or
  something the caller was meant to free. Copying at the boundary ends all three questions at once:
  the text a program holds is its own from the moment it arrives. A nought address is its own answer
  rather than the empty string, because a library saying it has no text and one saying its text is
  empty are different things.
- **An opened library is kept.** Opening one twice and holding two handles to the same code is how a
  library with internal state acquires two of it, and a graphics library is nothing but internal
  state.
- **Text is copied for the call and freed after**, which is what "borrowed for the call" means. A
  library that keeps the pointer is a library whose declaration is wrong, and nothing here can
  detect that.
- **The kind codes are shared with the C file and are not to be reordered.** One side knows the
  declaration and the other knows the machine; the codes are the only thing they agree on.
- Resource lifetime is delegated to [[Foreign Ownership]]. This module opens libraries, resolves
  symbols, and performs calls; it does not keep process-global ownership state.
- **A signature that cannot be assembled comes back as a value.** It is the one failure at this
  boundary that is recoverable, so it is reported rather than crashed on.

### Linkage

- **Requires:** [[Foreign Crossing]], `cbits/pudu_ffi.c`.
- **Used by:** [[Eval Foreign]].

## Grill Log

- **Q:** Enumerate call shapes as static imports instead of assembling a
  signature at run time? **A:** No. _Rationale:_ arity times argument class is a
  combinatorial set, and the shapes not enumerated are the ones a program
  discovers by crashing. _Rejected:_ a fixed wrapper table.
- **Q:** Place arguments by hand, using what is known about the calling
  convention, and avoid the dependency? **A:** No. _Rationale:_ integer and
  floating arguments are placed by different rules, and one counted into the
  wrong place arrives as whatever was already there — a wrong answer rather than
  a failure. The machine's own caller knows the rules for the machine.
  _Rejected:_ a hand-rolled boundary.
- **Q:** Close a library when nothing is using it? **A:** No. _Rationale:_ nothing
  here can know that, and closing one a call is about to use is worse than
  keeping it for the life of the program. _Rejected:_ reference counting handles.
- **Q:** Keep ownership beside the process-global opened-library cache? **A:** No. _Rationale:_
  libraries may be shared, but resource claims belong to one evaluation and must be torn down with
  it. _Rejected:_ a process-global address set.

## Referenced by

[[src/Pudu/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]] · [[Foreign Crossing]]
