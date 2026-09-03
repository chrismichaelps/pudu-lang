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
data ForeignHandle
data CrossedValue = CrossedInteger !Int64 | CrossedDouble !Double | CrossedText !Text

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
- **An opened library is kept.** Opening one twice and holding two handles to the same code is how a
  library with internal state acquires two of it, and a graphics library is nothing but internal
  state.
- **Text is copied for the call and freed after**, which is what "borrowed for the call" means. A
  library that keeps the pointer is a library whose declaration is wrong, and nothing here can
  detect that.
- **The kind codes are shared with the C file and are not to be reordered.** One side knows the
  declaration and the other knows the machine; the codes are the only thing they agree on.
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

## Referenced by

[[src/Pudu/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]] · [[Foreign Crossing]]
