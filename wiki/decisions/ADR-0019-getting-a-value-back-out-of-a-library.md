---
type: decision
status: ACCEPTED
date: 2026-09-04
tags: [decision, language, ffi, foreign, ownership]
aliases: [ADR-0019-getting-a-value-back-out-of-a-library]
---

# ADR-0019: Getting a Value Back Out of a Library

## Context

[[ADR-0018-calling-a-library-written-elsewhere]] lets a foreign function answer directly, including
with an owned opaque handle. That is enough for Raylib and not enough for the ordinary constructor
shape used by SQLite and many other C libraries: the function answers with a status and writes the
resource through a pointer supplied by its caller.

```c
int sqlite3_open(const char *filename, sqlite3 **ppDb);
```

Pudu can describe the status and it can own the database handle, but it cannot describe the slot
between them. Pretending the slot is an ordinary `Db` parameter asks the Pudu caller for a database
before the constructor has made one. Pretending the database is the direct result discards the
status and no longer describes the symbol being called. The library is therefore unreachable at
the operation that creates its first useful value.

This decision is about output slots: storage the caller supplies, the callee writes once during the
call, and Pudu reads after the call returns. It is not yet about a mutable buffer whose capacity and
contents exist before the call, and it is not a general pointer model.

## Decision

**An output slot is written `out name: Type` in the foreign parameter list.** It has a name because
the declaration is documentation as well as a bridge, but it is not an argument the Pudu caller
supplies:

```pudu
foreign "pudu_sqlite_binding" {
  type Db

  fn open symbol "pudu_sqlite_open"(
    path: Str,
    out db: owned Db by destroy
  ) -> Int32

  fn destroy symbol "pudu_sqlite_destroy"(db: Db) -> ()
}
```

The native call still receives both arguments. The Pudu call receives only `path`; the runtime
allocates the storage for `db`, passes its address, and reads it after `pudu_sqlite_open` returns.
`out`, `owned`, and `by` remain contextual words inside a foreign declaration rather than becoming
reserved throughout the language.

The small C binding surface forwards `pudu_sqlite_open` to `sqlite3_open` and implements
`pudu_sqlite_destroy` with the non-failing ownership contract the declaration requires. It cannot
name `sqlite3_close` directly as `by close`: that function returns a status, may report `SQLITE_BUSY`,
and leaves the connection open in that case. The current ownership model requires a release that
takes exactly one handle, returns unit at the native ABI, and completes the transfer. A binding may
wrap `sqlite3_close_v2`, whose deferred destruction fits that contract, or a later decision may add
fallible releases. Output slots solve how the handle arrives; they do not weaken how it leaves.

**A function with slots answers with one tuple: the native result first, then every slot in source
order.** The example above has the Pudu-side type:

```pudu
unsafe(foreign) fn(Str) -> (Int32, Option[Db])
```

The native result is present even when it is unit, so a function declared `-> ()` with one total
`Int32` slot answers `((), Int32)`. A stable rule is worth the apparently redundant unit: adding a
status result later must not move every slot, and generic tooling must not need a special case for
whether the native result happens to carry information.

A tuple uses a type the language, evaluator, formatter, and editor already understand. Inventing a
nominal record per foreign function would create a hidden declaration that cannot be named in
source, documented honestly, or navigated to. Requiring the binding author to declare a record for
every call would turn a one-line signature into two public declarations without adding a semantic
distinction. Slot names remain visible in hover, completion detail, and generated documentation;
tuple positions are their program representation.

**Scalar and by-value-record slots are total.** `out count: Int32` asserts that the library writes a
complete `Int32` before returning, on every native result. The runtime allocates valid zero-initialized
storage so the host call never receives indeterminate bytes, but zero is not evidence that a write
happened. Zero is a legitimate integer, false is a legitimate boolean, and an all-zero record may be
a legitimate record. There is no portable observation that distinguishes "the library wrote zero"
from "the library did not write" after both executions leave the same bytes.

That assertion belongs to the unsafe foreign declaration, just like the declared calling convention
and widths. If a C API writes a scalar only for some status values, its binding must expose the
status and document the relation, wrap the API through a C surface that makes the output total, or
wait for a later explicitly initialized in/out design. Pudu will not manufacture `Option[T]` from a
byte-pattern guess.

**Pointer-shaped slots are optional because pointers have a real absence representation.** The
runtime initializes the pointer cell to null. A null value after the call becomes `None`; a non-null
value becomes `Some(value)`:

| Declared slot | Pudu tuple element | Native storage |
|---|---|---|
| `out x: Int8` … `UInt64`, `Float32`, `Float64`, or `Bool` | the declared type | one value, zero-initialized |
| `out x: Record` | `Record` | one by-value record, recursively zero-initialized |
| `out text: Str` | `Option[Str]` | one `char *` cell initialized to null |
| `out h: owned Handle by release` | `Option[Handle]` | one opaque pointer cell initialized to null |

Returned text is copied and validated as UTF-8 before the native pointer's lifetime can matter,
exactly as for a direct text result. The declaration does not transfer ownership of that native text;
an API whose returned text must be released needs a later owned-buffer representation rather than a
false `Str` binding.

An opaque handle output must be `owned` and must name a same-block release function under the rules
already applied to direct handle results. Borrowed handles remain unrepresentable because their
lifetime remains unrepresentable. Null is not an error for a slot: it is `None`, and the native
status alongside it tells the program why. A non-null handle is claimed before the result tuple is
visible. This matters for `sqlite3_open`, which may return a non-null database handle even when its
status reports failure; the program must still be able to close that handle.

**The call is committed as one boundary operation.** Ordinary inputs are crossed and existing
handles are leased before dispatch. The native function runs once. Every non-null owned value it
produced is then classified before fallible text or record conversion begins. That set includes an
owned direct native result as well as every owned output slot; direct ownership may not commit first
and leave slot ownership to fail later.

Produced addresses already claimed by the evaluation are protected and never released. Fresh
addresses with one unambiguous release obligation are pending resources. The runtime then converts
every non-owning output, validates the pending ownership set, and atomically claims all pending
resources in one store transaction. Only after that transaction succeeds is the tuple exposed to
Pudu.

On any post-call conversion or claim failure, every unique fresh pending resource is released once
through its declared function before the primary failure is returned. A cleanup failure is attached
as a related runtime diagnostic; it does not replace the conversion or ownership failure that caused
cleanup. An address already owned is never released, because doing so would destroy the resource
behind the claim being protected.

The same fresh address produced more than once with the same canonical handle identity and release
obligation is released once while the duplicate-ownership violation is reported. If two outputs
attach different handle identities or release obligations to one fresh address, the runtime cannot
know which destructor is true: it reports the violated foreign contract, does not guess for that
address, and still releases every other unambiguous fresh resource. This is the one cleanup case the
declaration itself has made unknowable, and pretending otherwise would turn a leak into a possible
wrong-destructor fault.

**Slots consume native bridge capacity but not Pudu call arity.** Every ordinary parameter and every
slot occupies one native argument position and together remain under the bridge's 32-argument limit.
Only ordinary parameters appear in the function type presented to callers. A release function may
not declare slots: a release remains exactly one ordinary parameter of its handle type, and its
native result remains unit under [[ADR-0018-calling-a-library-written-elsewhere]].

**Only shapes that already cross may be slots.** Unit is not a slot value. A handle cannot sit inside
a record slot. Recursive records, arbitrary pointers, arrays, callbacks, borrowed values, and
pointer arithmetic remain refused at the declaration. Adding `out` does not weaken any crossing
rule; it changes which side supplies the storage for an admitted shape.

## Buffers Are a Different Contract

A buffer argument such as `void read(char *bytes, size_t capacity)` is not an output slot. The
caller owns useful storage before the call, a second value bounds how much may be written, and the
answer may occupy only a prefix. Treating that as `out Str` would allocate the wrong representation,
lose the capacity relation, and scan for a terminator the API may never write.

[[ADR-0020-handing-a-library-a-run-of-bytes]] takes the first part of that separate decision, and
finds that "buffers" is three contracts rather than one: sixty-three functions across four libraries
pass a run the library only reads, against nine it writes into and ten it allocates. Buffers
therefore follow slots in a separate decision. They need a bounded byte value, an explicit
capacity relationship, mutation confined to the call, and a rule for the initialized length. Slots
come first because they reuse existing scalar, record, text, and owned-handle crossing while making
whole opaque-handle libraries reachable. Neither design is allowed to masquerade as the other.

## Static and Editor Meaning

The parser retains whether each foreign parameter is ordinary or output. Resolution and checking
still resolve its written type and release name at the declaration. The checker derives two related
signatures:

- the native signature, containing ordinary parameters and slots in source order;
- the Pudu signature, containing only ordinary parameters and answering the result-and-slots tuple.

Hover shows the source declaration and the derived Pudu callable type, including each slot name and
whether it becomes optional. Completion uses the Pudu callable type, so it never asks the caller to
invent an output value. Definition still leads to the foreign declaration. Diagnostics belong on
the slot that violates crossing, ownership, release-shape, or capacity rules.

Inference treats the returned tuple exactly as a tuple written in Pudu. No foreign-only projection
or destructuring rule is introduced.

## Consequences

SQLite and other C libraries whose constructors return status through the native result and a
resource through `T **` become describable without exposing pointers as integers. Programs retain
both facts: success or failure as the library defines it, and the resource when the library produced
one. Existing direct results and direct owned results retain their current source and runtime
meaning.

The declaration author accepts a sharper obligation for total scalar and record slots: Pudu can
make the storage valid, but only the foreign contract can say whether the library wrote it. Pointer
outputs avoid that ambiguity because null is an actual representation the API can leave behind.
Tuple answers are positional, so reordering slots is an API change even though their names remain in
the declaration and tooling.

The runtime gains temporary native storage and an atomic batch-claim operation. It does not gain a
general address value, an escape route around handle ownership, or a mutable buffer visible to safe
Pudu code.

## Alternatives Rejected

**Pass a placeholder from Pudu.** Rejected. There is no safe value of an unconstructed handle type,
and exposing a null or raw pointer solely to satisfy the call would make the unsafe implementation
detail part of every caller.

**Return only the slots and discard a unit or status result.** Rejected. The declaration describes a
real native result, and status-plus-output APIs need both. Changing tuple shape based on result type
would make the derived signature harder to read and mechanically consume.

**Synthesize a named record.** Rejected. A compiler-created nominal type has no honest source
definition, while a user-created record adds ceremony and a conversion for no additional safety.

**Use zero as a universal absence sentinel.** Rejected. Zero, false, zero-valued floats, and
all-zero records are valid values. Only a null pointer carries a distinct absence meaning here.

**Build buffers first or call every pointer a slot.** Rejected. A buffer has pre-call contents,
capacity, partial initialization, and usually borrowed ownership. A slot has storage but no Pudu
value before the call. Conflating them would hide the invariants the boundary needs to enforce.

## Validation Required Before Implementation Is Complete

- A C conformance fixture returns a status and writes every admitted scalar class and a nested
  by-value record through slots, including legitimate zero values.
- The fixture writes valid text, invalid UTF-8, and null through a text slot; only null becomes
  `None`.
- An owned-handle constructor proves success with a handle, failure with a handle that must still be
  released, and null without a fabricated resource.
- Multiple handle slots are claimed atomically; duplicate output addresses and an address already
  owned are refused without corrupting an existing claim.
- Parser, formatter, resolver, checker, diagnostics, hover, completion, definition, and interface
  export tests cover the source declaration and derived callable signature.
- A real SQLite integration through the small C binding surface opens an in-memory database, then
  deliberately attempts an open that returns failure with a non-null handle and proves both handles
  are destroyed. The deterministic conformance fixture owns the null-output branch; allocator fault
  injection is not a stable ecosystem test.
- Existing Raylib and C++ C-ABI fixtures pass unchanged, proving that direct results and direct owned
  results did not move.

## Grill Log

- **Q:** Is zero evidence that a scalar slot was not written? **A:** No. _Rationale:_ a write of zero
  and no write leave indistinguishable storage. _Rejected:_ guessing `Option` from the bytes.
- **Q:** Hide the native result when slots exist? **A:** No. _Rationale:_ it often carries the status
  that gives the slots meaning. _Rejected:_ returning only the outputs.
- **Q:** Make a different record type for every call? **A:** No. _Rationale:_ the language already
  has positional product types, while a synthetic nominal type has no source declaration.
  _Rejected:_ compiler-created result records.
- **Q:** Return a handle only when status means success? **A:** No. _Rationale:_ the foreign library
  owns that relation, and SQLite may produce a handle that must be closed on failure. _Rejected:_ a
  generic status convention in the runtime.
- **Q:** Name `sqlite3_close` directly as an owned release? **A:** No. _Rationale:_ it is fallible,
  returns `Int32`, and may leave a busy database open, while an owned release must complete and
  return unit. _Rejected:_ lying about the native ABI or treating attempted release as destruction.
- **Q:** Let an output pointer be borrowed? **A:** No. _Rationale:_ the language cannot yet state how
  long the borrow remains valid. _Rejected:_ a handle whose liveness ends by convention.
- **Q:** Treat buffers as output slots? **A:** No. _Rationale:_ capacity and initialized length are
  part of a buffer's contract and absent from a slot. _Rejected:_ an unbounded writable pointer.

## Referenced by

[[ADR-0018-calling-a-library-written-elsewhere]] · [[ADR-0020-handing-a-library-a-run-of-bytes]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[architecture/STDLIB]] · [[2026-09-04-foreign-out-slots]]
