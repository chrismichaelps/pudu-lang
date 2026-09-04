---
type: decision
status: PROPOSED
date: 2026-09-04
tags: [decision, language, ffi, foreign, bytes]
aliases: [ADR-0020-handing-a-library-a-run-of-bytes]
---

# ADR-0020: Handing a Library a Run of Bytes

## Context

[[ADR-0019-getting-a-value-back-out-of-a-library]] settled how a library hands a value back, and
deferred buffers with a note that they are a different contract. This decides the first part of that
contract, and says plainly which parts it does not decide.

Counting declared functions in four libraries, and separating the shapes rather than calling them all
"buffers":

| Shape | sqlite3 | libcurl | zlib | raylib |
|---|---|---|---|---|
| a run the library **reads**, with its length beside it | 21 | 6 | 12 | 24 |
| a run the library **writes into**, the caller owning the storage | 1 | — | 1 | 7 |
| a run the library **allocates** and the caller releases | — | 1 | 1 | 8 |

Counted from the headers as installed: `sqlite3.h`, `curl/curl.h`, `zlib.h` from the platform SDK,
`raylib.h` from raylib 6.

Sixty-three against nine against ten. The run a library only reads is not merely the largest of the
three, it is most of the subject, and it is also the only one of the three with no lifetime question
in it: the library reads during the call and the call ends.

## What is already reachable

Part of what the first column counts needs nothing new. A `const char *` with a length beside it is
text, and text already crosses:

```pudu
fn prepare symbol "sqlite3_prepare_v2"
  (db: Db, sql: Str, length: Int32, out statement: owned Statement by finalize, out tail: Str) -> Int32
```

checks today and answers `Db -> Str -> Int32 -> (Int32, Option[Statement], Option[Str])`. The length
is an ordinary argument because in C it is an ordinary argument, and `-1` meaning "to the first
nought" is the library's convention rather than the boundary's.

What is refused is a run of **bytes**:

```
error[E3063]: this type cannot cross a foreign boundary
  = help: what may cross: Int8 … Float64, Bool, Str, (), and a type the block itself declares
```

`Bytes` is already a Pudu value with contiguous storage — it exists because an array of byte-sized
values held one runtime value per byte does not fit input measured in gigabytes. It is the right
thing to hand a library, and the boundary does not admit it.

## Decision

**`Bytes` crosses as the address of its bytes, for the duration of the call, and the library may only
read them.**

```pudu
foreign "z" version "1" {
  fn adler symbol "adler32" (running: UInt64, data: Bytes, length: UInt32) -> UInt64
}
```

Four things follow.

**The length is an ordinary parameter.** The declaration mirrors the native signature, because that
is what a foreign declaration is for. Pudu's `Bytes` knows its own length, so writing
`adler(1, data, data.length())` says the same thing twice — and the second saying is where a mistake
would go. That is a real cost, and it is accepted here rather than hidden: a boundary that silently
supplied the length would be inventing an argument the C function's callers do not have, and the
first library whose length parameter means something else — a stride, a count of elements rather than
bytes, a capacity — would be described wrongly by a declaration that looked right. What the language
can do about that is a later decision, named below.

**The bytes are borrowed for the call and nothing else.** They are Pudu's storage, alive because the
value is alive, and the address is valid for exactly as long as the call. A library that keeps the
pointer is a library this declaration cannot describe, in the same way a borrowed handle is a result
this language does not yet represent.

**The library may not write them.** A `Bytes` value is a value, and two values that compare equal
must stay equal; a library writing through the address would change one of them underneath the
program. The parameter is what a C signature spells `const`, and a declaration naming a native
function that writes is an assertion that was wrong, which is what `unsafe` already covers.

**A record field may not be `Bytes`.** A record crosses by value as its flattened leaves, and a run
of bytes is not a leaf: it is an address plus a length that no field names. A record holding one is
refused where it is written, as a record holding a handle already is.

## What This Does Not Decide

**A run the library writes into.** Nine functions across the four libraries. The caller owns useful
storage before the call, a second value bounds how much may be written, and the answer may occupy
only a prefix — so it needs a mutable byte value, a stated capacity, and a rule for how much of it is
live afterwards. `zlib`'s `uncompress(Bytef *dest, uLongf *destLen, …)` needs all three at once, its
length parameter being both the capacity going in and the written length coming out.

**A run the library allocates.** Ten functions, and raylib's `LoadFileData`, `CompressData` and
`DecompressData` are the shape: the result is an address the caller must release, and the length
arrives through a slot beside it. Output slots already carry the length. What is missing is a byte
value that owns storage it did not allocate, and whose release is named the way a handle's is.

**Saying what the length parameter means.** The cost accepted above is a caller writing a length that
must agree with a buffer. A declaration could name the relation — that this parameter is that
parameter's length — and then the boundary would supply it and a mismatch would be impossible rather
than merely unlikely. That is worth having and is not this decision, because it is a general
statement about arguments rather than a fact about bytes.

## Alternatives Rejected

**Admit a pointer and a length as two ordinary scalars.** Rejected: it is what a program does today
by not being able to do this at all, and it means an address becomes an integer, which is the one
thing every part of this boundary has refused. An integer that is an address can be stored, arithmetic
can be done on it, and nothing recovers the fact that it pointed at something.

**Let `Bytes` be written by the library.** Rejected here rather than merely deferred: a value that
changes when a library is called is not a value, and every equality, hash, and comparison already
computed on it would be wrong. A run the library writes into needs its own type, not permission to
mutate this one.

**Supply the length automatically from the value.** Rejected for now, and the reason is stated above
rather than dismissed: the relation is worth naming, but naming it belongs to a decision about
arguments in general, and guessing it from position or spelling would describe some libraries wrongly
while looking right.

**Wait and do all three buffer shapes together.** Rejected. The three differ in ownership, mutability,
and lifetime — the properties the boundary exists to police — and building them as one would settle
those questions once for cases that answer them differently. Sixty-three functions need only the
simplest of the three.

## Validation Required Before Implementation Is Complete

- A C conformance fixture reads a run of bytes and reports something derived from all of them, so a
  truncated or misaligned crossing is visible rather than plausible.
- Empty bytes cross as an address that is not nought with a length of zero, since a library reading
  zero bytes from a valid address is ordinary and a nought address is not.
- Bytes containing noughts cross whole, which is the difference between `Bytes` and `Str` and the
  reason both exist.
- A `Bytes` field in a record, and a `Bytes` result, are refused at the declaration.
- Text with a length beside it keeps working, and the existing scalar, record, text, handle, and slot
  fixtures are unchanged.

## Referenced by

[[ADR-0018-calling-a-library-written-elsewhere]] · [[ADR-0019-getting-a-value-back-out-of-a-library]]
· [[grammar/pudu]] · [[Foreign Crossing]]
