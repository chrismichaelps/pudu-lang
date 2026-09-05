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
resolveSymbol :: Text -> Maybe Text -> Text -> IO (Either Text (Ptr ()))

data ForeignHandle
data ForeignCallFailure = CallAssemblyFailure !Text | InvalidReturnedText
                        | PostCallFailure !ForeignCallFailure ![(Maybe Int, Text, Int64)]
data CrossedValue = CrossedInteger !Int64 | CrossedDouble !Double | CrossedText !Text
                  | CrossedHandle !Text !Int64 | CrossedRecord !Text ![(Text, CrossedValue)]
                  | CrossedNoText

openLibrary   :: Text -> Maybe Text -> IO (Either Text ForeignHandle)
candidates    :: Text -> Maybe Text -> [Text]
findSymbol  :: ForeignHandle -> Text -> IO (Either Text (Ptr ()))
callSymbol  :: Ptr () -> [(Crossing, Bool, CrossedValue)] -> Crossing
            -> IO (Either ForeignCallFailure (CrossedValue, [Maybe CrossedValue]))
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
- **`Str` means UTF-8 bytes, never the host locale.** Direct text and text stored as a pointer field
  in a flat record use the same encoding and lifetime. Invalid bytes returned by a library are a
  boundary refusal; replacement text would be a different value from the one the library returned.
- **The integer carrier preserves bits; the declaration restores meaning.** Native argument/result
  storage is 64 bits wide. In particular, the upper half of `UInt64` may look negative in that
  carrier, but becomes its original unsigned Pudu integer before leaving the boundary.
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
- **Q:** Decode returned bytes with the process locale? **A:** No. _Rationale:_ Pudu source and
  strings are Unicode, and the same library call must not mean different text because one host was
  started under a different locale. _Rejected:_ locale-dependent `CString` conversion; lossy UTF-8.

## Post-call conversion failures

`PostCallFailure ForeignCallFailure [(Maybe Int, Text, Int64)]` retains every non-null top-level
handle produced by the native result or slots. The bridge captures these addresses before decoding
any returned text. This lets the evaluator discharge ownership even when UTF-8 decoding fails.

### Resolved Grill

- **Q:** Discard raw outputs on invalid text? **A:** No; preserve resource addresses on the failure
  path. Text validity cannot erase a native release obligation.

## Native output provenance

Retained handles include their native parameter index (`Nothing` for the direct result). Cleanup
uses that exact declaration's destructor, so two outputs of the same type may name different release
functions without being conflated. A missing or mismatched obligation is reported without guessing.

### Resolved Grill

- **Q:** Recover a release using only the handle's type name? **A:** No; source position identifies
  the producer obligation, while the type only identifies the nominal value.

## Naming a library

`candidates` lists what to ask the loader for, in the order a person would: what the declaration
wrote, then the versioned spellings, then the unversioned ones. The version belongs inside the file
name and each platform puts it in a different place — `libcairo.so.2`, `libcairo.2.dylib`,
`libcairo-2.dll`.

Versioned first, because the unversioned name is usually a symlink shipped for building against: a
machine holding the library and not its headers has only the versioned one. The unversioned names are
still reached afterwards, so this only ever adds names that would not have been tried. Nothing here
can check that what opened is the ABI the declaration named.

Open libraries and resolved symbols are cached by name *and* version, so two blocks naming the same
library at different versions do not share one handle.

### Resolved Grill

- **Q:** Refuse to fall back to the unversioned name when a version is declared? **A:** No. It cannot
  be verified either way, and refusing would break the machine where the unversioned name is the
  installed runtime, in exchange for a guarantee this layer cannot make.

## Referenced by

[[src/Pudu/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]] · [[Foreign Crossing]]
