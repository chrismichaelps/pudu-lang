---
type: decision
status: PROPOSED
date: 2026-11-13
tags: [decision, language, ffi, foreign, ownership, native]
aliases: [Foreign Pointers and Runs, ADR-0030]
---

# ADR-0030 — Pointers, runs and function pointers across a foreign call

## Context

[[ADR-0018-calling-a-library-written-elsewhere]] admits opaque handles and
defers every other pointer. [[ADR-0019-getting-a-value-back-out-of-a-library]]
covers storage a library only writes, and
[[ADR-0020-handing-a-library-a-run-of-bytes]] covers a run of bytes it only
reads. Platform APIs need four more shapes:

- a pointer to one value the library reads, or reads and writes: `frexp`'s
  `int *`, `nanosleep`'s `const struct timespec *` and `struct timespec *`;
- a run of typed elements the caller owns: `getloadavg(double[], int)`,
  `bzero(void *, size_t)`, `memcmp(const void *, const void *, size_t)`;
- a pointer that may be null: `fopen` answering `NULL`, `fflush(NULL)`;
- a function pointer, which ADR-0028 (foreign callbacks and thread affinity)
  builds from a callback type and a context.

A pointer has two questions an integer does not: whether it may be absent,
and how long what it names stays valid. Every shape below answers both in the
declaration, and the answer is the same in the interpreter's bridge and in a
native program.

## Decision

### A pointer to one value is a lent place

A foreign parameter may be written `&T` or `&mut T`:

```pudu
type Timespec = { seconds: Int64, nanos: Int64 }
foreign "c" {
  fn frexp(value: Float64, exponent: &mut Int32) -> Float64
  fn nanosleep(request: &Timespec, remaining: &mut Timespec) -> Int32
}
```

- `T` is a fixed-width integer, `Float32`, `Float64`, `Bool`, or a record
  whose leaves are all of those, nested records included, at most 32 fields
  each. Text, `Bytes`, handles, `()`, and references behind a scalar or record loan
  are refused (`E3095`).
- `&T` crosses as `const T *`: the address of a copy that lives for the call.
  The caller writes `&value`.
- `&mut T` crosses as `T *`: the place's value is copied in, the call runs,
  and what the library left is stored back into the place. The caller writes
  `&mut place`, under the rules [[ADR-0022-lending-a-place]] already enforces:
  the place must be writable, two loans to one call may not overlap, and
  nothing else observes the place during the call, so copying in and out is
  indistinguishable from writing through its address.
- The address is valid for the call and never longer. A library that keeps it
  is a declaration that is wrong, as for `Bytes`.
- A lent place is never null. It may not be a result or an output slot
  (`E3094`). A record field that lends is a field that does not cross
  (`E3063`), and ADR-0028 refuses it as a callback parameter.

### A run of elements is a lent array

```pudu
foreign "c" {
  fn getloadavg(samples: &mut Array[Float64], count: Int32 elements of samples) -> Int32
  fn bzero(target: &mut Array[Int32], length: UInt64 bytes of target) -> ()
}
```

- An element is a fixed-width integer, a float, `Bool` or a record that can
  cross behind a lent pointer. Record runs use the target's C `sizeof(T)`
  as stride, including tail padding. The bridge initializes and reads the
  fields at their ABI offsets. Padding is outside the Pudu value.
- `&Array[T]` crosses as `const T *` to the elements laid end to end at their
  natural width, copied for the call. `&mut Array[T]` crosses as `T *`; the
  library may write any element, and the final elements are stored back into
  the place. The number of elements never changes.
- An empty array crosses as an address that is not null and has no elements,
  as empty `Bytes` does.
- `Array[T]` by value is refused (`E3096`): an array has no C value form, and
  a C array parameter is a pointer.

### A length may say what it measures

```ebnf
foreign_parameter = "out"?, identifier, ":", ("owned" | "nullable")?, type,
                    (("by", identifier) | (("elements" | "bytes"), "of", identifier, ("and", identifier)*))? ;
```

`count: Int32 elements of samples` and `length: UInt64 bytes of target`
relate an integer parameter to a run in the same declaration: `Bytes`,
`&Array[T]` or `&mut Array[T]`. The caller still writes the argument, so the
declaration keeps the library's own signature. Before the library runs, the
boundary refuses a value below zero or above the run's element count, or its
byte size, with `E7028` in both runtimes. A library told a smaller length is
ordinary; one told a larger length would write past storage the program
owns. The boundary checks extent arithmetic before converting to the
target allocation size, and refuses overflow with the same diagnostic.

One length can bound several runs. For example, a declaration can write
`length: UInt64 bytes of left and right` for `memcmp`. Every named run must
hold at least the requested extent. Check relationships in declaration order
and targets within a relationship in written order, before any foreign code
runs. A relation on a slot, on a non-integer parameter, or naming an invalid
or repeated run is `E3098`. The declaration asserts that the library honours
the length and names every buffer governed by it.

### Nullable loans

A foreign parameter can explicitly opt into absence with
`argument: nullable &T` or `argument: nullable &mut T`, including run
pointees. In that argument position, literal `None` crosses as null and a
present argument uses the ordinary `&value` or `&mut place` form. A
present loan follows the same overlap and writeback rules as a non-null
loan. An absent loan has no writeback destination. The checker elaborates
the two argument forms at a direct foreign call without introducing a
reference-valued `Option`. Taking a foreign function with a nullable loan
as a first-class function requires a separate function-type contract.

An absent run has extent zero for every related length. A present empty run
still has a non-null address. Thus a positive length paired with absence is
refused before dispatch, and a zero length preserves the distinction between
null and an empty buffer.

### Returned runs are copied while the allocation is live

An owned array result names an integer output slot that reports its length
and a release function that accepts the original pointer. The result
crossing adds `elements of <slot> by <release>` after the array type.
The length slot must be a fixed-width integer output in the same
declaration. The proposed declaration form is:

```pudu
foreign "buffer" {
  type SampleStorage
  fn read(out length: UInt64) -> owned Array[Int32] elements of length by freeSamples
  fn freeSamples(storage: SampleStorage) -> ()
}
```

The release declaration's opaque handle identifies the native pointer
argument. The wrapper resolves the release before calling the producer. The
slot remains in the existing result tuple, and the result component is a
Pudu-owned copy. The producer must initialize the length on every return and
guarantee the extent of initialized elements and exclusive ownership of any
non-null allocation. Validate signed lengths, target-size arithmetic and
allocation size before reading. The native signature and the interpreter
must agree on layout and stride for each element.

The release runs exactly once for every valid transferred non-null pointer,
including a zero-length allocation and a refusal during conversion. Register
the transfer before decoding the slot or copying any element so failure
cleanup still owns the pointer. A pointer
already claimed by the runtime is a duplicate transfer and remains owned by
the existing claim. Null with positive length is a refusal. Null with zero
length is allowed only for an explicit `owned Option[Array[T]]` result, where
it becomes `None`; a non-null pointer with zero length becomes `Some([])`
for that result. The boundary never releases null. A borrowed returned run
needs a separate lifetime contract.

### A handle that may be null uses Option

```pudu
foreign "c" {
  type File
  fn fopen(path: Str, mode: Str) -> owned Option[File] by fclose
  fn fflush(file: Option[File]) -> Int32
  fn fclose(file: File) -> Int32
}
```

- `Option[T]` for a handle type the block declares is a pointer that may be
  null. As a parameter, `None` crosses as null and `Some(handle)` crosses as
  the handle, checked live and leased exactly as a direct handle is.
- As a result, null becomes `None` and anything else becomes `Some`, claimed
  under the written mode: `owned Option[T] by release`,
  `counted Option[T] by release`, or `borrowed Option[T]`. A result written
  without `Option` still refuses null at run time (`E7020`), so the absence is
  in the declaration or it is a failure.
- Outside the returned-run form, a foreign `Option` whose payload is not a
  handle is refused (`E3097`): a scalar has no absence, and
  text already answers `Option` where it is a slot. A slot is not written
  `Option`, since a pointer slot already answers one. A release still takes
  exactly its handle (`E3067`).

### A pointer the program holds is a handle

There is no general `Ptr[T]` value. A pointer the library hands back is an
opaque handle of a type the block declares, with its existing owned, counted
and borrowed claims and generation checks. Pudu code never reads or writes
through one. A program that needs the bytes behind a handle declares the
library's own read routine with a lent run as its target and a length
related to it, so the side Pudu owns is bounded and the side the library
owns is the declaration's assertion:

```pudu
fn readInto symbol "buffer_read"(source: Buffer, target: &mut Array[UInt8],
  length: UInt64 bytes of target) -> Int64
```

### Function pointers

These forms are decided here and implemented with the callback runtime
(#876), which they need.

- A parameter of a declared callback type crosses as that type's trampoline,
  with its `context` partner in the same function, as ADR-0028 states.
- A library that takes the function and the context in separate calls is
  declared with two parameter forms. `handler: trampoline OnTick` passes the
  trampoline of `OnTick` and takes no Pudu argument. `data: context OnTick`
  takes an `OnTick` registration and passes its key. A registration's key
  lives until `unregister()`, so it may be handed over before or after the
  trampoline.
- A library that shares one context among several callbacks is declared with
  `callbacks Delegate { tick: OnTick, close: OnClose }`. `Delegate(record)`
  registers one function per field and answers one token, `context Delegate`
  passes its key, and `trampoline Delegate.tick` passes the trampoline that
  routes that key to the `tick` function.
- A callback parameter may be a run of bytes: `data: Bytes` with
  `length: UInt64 bytes of data` beside it. The trampoline copies that many
  bytes into a new `Bytes` value before the body runs, refusing a null address
  with a nonzero length as a failure of the invocation.
- A function pointer a library returns is not a value Pudu can call. A
  function a library exports is reached through a declaration.

### Layout per target

Scalar widths are the declared ones. An element run has the element's natural
size as its stride and no padding between elements. A record behind a pointer
has the platform's layout: the native program declares the C struct from the
record, and the interpreter asks its call library for each field's offset.
Neither calculates offsets itself. Pointers have the target's address width.

### Still refused

- A variadic function: `fn printf(format: Str, ...)` is `E3099`. A variadic
  call places arguments by rules the declaration cannot state; a library's
  fixed-argument form, or a C surface, binds it.
- A union: a sum type or enum named as a crossing is `E3063`, with help
  naming unions. Its storage overlaps, and which member is live is not in the
  declaration.
- A bit-field: a record field is a whole scalar, and Pudu has no spelling for
  a bit-field. A struct holding one is bound through a C surface.

## Delivery

The first implementation partition covers non-null lent scalar and record
places in the checker, interpreter and native code. Scalar runs, length
relations and nullable handle crossings follow. Function pointers depend on
the registration and trampoline runtime in #876. Record runs, nullable
typed loans and returned runs are later implementation partitions.
Acceptance for #877 includes both execution paths and target ABI evidence.

This decision proposal changes no currently accepted program.

## Grill Log

- **Q:** Model a pointer as a `Ptr[T]` value with unsafe reads? **A:** No.
  _Rationale:_ a pointer whose extent is unknown makes every read unchecked,
  and a lent place or run covers the shapes platform APIs pass. A held
  pointer is a handle. _Rejected:_ `Ptr[T]` with `unsafe(raw)` reads in this
  slice.
- **Q:** Write through the caller's storage for `&mut`? **A:** No; copy in
  and out. _Rationale:_ ADR-0022 makes the place unobservable during the
  call, so the two are indistinguishable, and a place may be a field or an
  element of a shared value whose other holders must not see the write.
  _Rejected:_ passing the address of frame storage.
- **Q:** Allow `&mut Bytes`? **A:** No. _Rationale:_ `Bytes` is a value and
  stays unchanging (ADR-0020). A writable run is `&mut Array[UInt8]`.
  _Rejected:_ mutable `Bytes` aliases.
- **Q:** Supply the length from the run? **A:** Not yet; check it.
  _Rationale:_ the declaration keeps the library's signature, the relation
  names the run, and a mismatch is refused before the call. Supplying it is a
  separate question about argument lists. _Rejected:_ a length guessed from
  parameter position or name.
- **Q:** Bound a length by equality? **A:** No, by at most the run.
  _Rationale:_ libraries are routinely told to use a prefix; only a larger
  value reaches storage the program does not own. _Rejected:_ exact-length
  refusals.
- **Q:** Spell nullable results `-> Option[owned T by r]`? **A:** No,
  `-> owned Option[T] by r`. _Rationale:_ the mode and release belong to the
  result, as they already do, and `Option[T]` stays an ordinary type the
  checker forms. _Rejected:_ ownership modes inside type arguments.
- **Q:** Make `Option[Int32]` mean a pointer to an integer that may be null?
  **A:** No. _Rationale:_ `Option` here means a null pointer, and a scalar
  crosses by value. Nullable lent places use a parameter modifier because
  `&mut` cannot sit inside a type argument. _Rejected:_ `Option` meaning two
  things at one boundary.
- **Q:** Admit variadic calls with the arguments' own types? **A:** No.
  _Rationale:_ arm64 platforms place variadic arguments differently from
  fixed ones, so one declaration cannot describe every call. _Rejected:_
  typing each variadic call site.
- **Q:** Admit unions by declaring their largest member? **A:** No.
  _Rationale:_ which member is live and the union's alignment are not
  recoverable from one member. _Rejected:_ largest-member unions.
- **Q:** Let a separate set-context call take the trampoline implicitly?
  **A:** No. _Rationale:_ each native position is written in the declaration,
  as everywhere else at this boundary. _Rejected:_ implicit trampoline
  arguments.

## Consequences

- New diagnostics: `E3094` a lent place or run as a result or slot;
  `E3095` a lent place or run whose target does not cross; `E3096` an array
  by value; `E3097` an optional that is not a handle; `E3098` a length
  relation that names no run; `E3099` a variadic declaration; `E7028` a
  length outside its run, at run time.
- [[Native Foreign Call Sites]] gains lent places, lent runs and optional
  handles. A wrapper that lends `&mut` answers its result beside each final
  value, and the caller stores them through the place as every loaned call
  does ([[Native Mutable Loans]]).
- [[architecture/FFI-SELF-HOSTING]]'s writable-buffer row would be met for runs of
  scalars; returned buffers remain.

## Referenced by

[[decisions/_MOC]] · [[ADR-0018-calling-a-library-written-elsewhere]] ·
[[architecture/SEMANTICS]] · [[grammar/pudu]] ·
[[architecture/FFI-SELF-HOSTING]] · [[Foreign Pointer Delivery]]
