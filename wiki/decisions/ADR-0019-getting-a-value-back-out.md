---
type: decision
status: PROPOSED
date: 2026-09-04
tags: [decision, language, ffi, foreign, unsafe]
aliases: [ADR-0019-getting-a-value-back-out]
---

# ADR-0019: Getting a Value Back Out of a Library

## Context

[[ADR-0018 Calling a Library Written Elsewhere]] settled how a program reaches a library, and what has
been built on it reaches a good deal: scalars at stated widths, text as UTF-8, records by value
including records of records, and opaque handles whose release is named in the declaration.

The remaining shapes were about to be ranked by measuring one library. That was the wrong method, and
correcting it changed the answer.

## What one library said, and why it was not enough

raylib is convenient to measure — a large, ordinary C surface — and 288 of its 548 functions are
reachable today. Counting what blocks the other 260, three quarters is one shape: a struct the
library owns, passed or returned **by value**, with a pointer inside — `Image`, `Font`, `Sound`,
`Mesh`. A hundred and eight functions return one.

That is a real shape and it is worth supporting. It is also, it turns out, a habit of this library
rather than of libraries. Counting declared functions in three more, chosen for being ordinary rather
than for being convenient — each function counted once per shape it uses, so the columns do not sum
to the total:

| Shape | sqlite3 | libcurl | zlib | raylib |
|---|---|---|---|---|
| opaque pointer, `struct T*` | 169 | 25 | — | — |
| buffer or scalar pointer | 89 | 22 | 20 | 98 |
| **out-pointer, `T**`** | **25** | 1 | — | 2 |
| struct returned by value | — | — | — | 108 |
| *functions declared* | *216* | *43* | *67* | *548* |

Counted from the headers as installed: `sqlite3.h`, `curl/{curl,easy,multi}.h` and `zlib.h` from the
platform SDK, `raylib.h` from raylib 6.

zlib is the odd one: it has no opaque type at all, because the caller owns the `z_stream` and fills
its fields. That is its own shape and it is not what the others do.

Most C libraries do not hand back structs. They hand back an **opaque pointer**, which Pudu's handles
already cover — and they hand it back **through a slot the caller provides**:

```c
int sqlite3_open(const char *filename, sqlite3 **ppDb);
int sqlite3_prepare_v2(sqlite3 *db, const char *sql, int n,
                       sqlite3_stmt **ppStmt, const char **pzTail);
```

The return value is the error code. The thing you actually wanted arrives in `ppDb`. This is the
standard way a C library gives you a resource and tells you whether it worked, and it is why the
counting matters: **SQLite cannot be opened from Pudu at all.** Not a function here or there — the
constructor. A handle only ever arrives as an owned result, so there is no value of the handle's type
to pass in, and no way to say "a slot for one".

That is a harder blocker than raylib's 196, because it is the difference between a library being
partly reachable and being wholly unreachable.

## Decision

**A library may hand a value back through a slot, and the declaration says which arguments are
slots.**

```pudu
foreign "sqlite3" version "3" {
  type Db
  type Statement

  fn open symbol "sqlite3_open" (path: Str, out db: owned Db by close) -> Int32
  fn close symbol "sqlite3_close" (db: Db) -> Int32

  fn prepare symbol "sqlite3_prepare_v2"
    (db: Db, sql: Str, length: Int32, out statement: owned Statement by finalize, out tail: Str)
    -> Int32
  fn finalize symbol "sqlite3_finalize" (statement: Statement) -> ()
}
```

`out` marks a parameter the library writes rather than reads. The caller does not supply a value for
it; the boundary provides the slot, and what the library leaves there comes back to the program.

Four things follow.

**A call with slots answers with everything it produced.** `open` above is `fn(Str) -> (Int32, Db)`
from the program's side: the declared result and each slot, in the order written. There is no
out-parameter in Pudu, because a value arriving through an argument is exactly the thing this
language does not have — so it arrives the way every other value does.

**A slot may be owned, and ownership works as it already does.** `out db: owned Db by close` claims
the handle the moment it arrives, so the store leases it, refuses a second release, refuses use after
release, and releases it at teardown if the program did not. That is [[Foreign Ownership]] unchanged;
the only new part is where the value came from.

**A slot the library did not fill is not a value.** Most of these functions signal failure through
the return code and leave the slot untouched. The boundary cannot tell a written slot from an
unwritten one by looking, so it does not guess: the slot is zeroed before the call, and a slot that
is still zero after it comes back absent rather than as a handle to address zero. What the program
does about that is its own business — the error code is right there beside it.

**Only what already crosses may be a slot.** A slot for a handle, a scalar, or text — the shapes
whose meaning is already settled. A slot for a record, or a slot for a slot, is refused where it is
written until each has its own answer.

## What this does not decide

**A struct the library owns, returned by value, with a pointer inside.** raylib's `Image` and its
kin — 108 functions return one there, and none of the other three libraries returns a struct at all.
It needs a declared layout, because a value passed by register cannot be a black box: a struct of two
floats and a struct of eight bytes go to different places at the same size. That is a separate
decision and it should be taken on its own evidence rather than folded in here.

**Buffers.** `void*` and `unsigned char*` with a length beside them: 229 functions across the four
libraries, and the only shape every one of them uses. Reading and writing bytes the library owns is
its own lifetime question and deserves its own answer.

**Callbacks, and a pointer as an ordinary type.** Unchanged from
[[ADR-0018 Calling a Library Written Elsewhere]].

## Alternatives Rejected

**Let the program make a slot and take its address.** Rejected: it means admitting an address as an
ordinary value, and then every question this design avoids — what it points at, how long it lives,
who frees it — arrives at once, for the sake of a shape the declaration can describe instead.

**Return the slots as one record.** Rejected: a record whose fields are a code and a handle has to be
declared somewhere, and the name would be invented per function. A call answering with what it
produced needs no name.

**Fit the design to raylib and generalise later.** Rejected, and it is what this decision started out
doing. A design measured against one library is a design shaped by that library's habits; raylib
returns structs by value where most libraries return opaque pointers through slots, and had the
ranking stood, the first slice would have been the one that mattered least to everything except
raylib.

## Validation

The mechanism has to be proven against a real installed library rather than a fixture, because the
shape exists to serve what real libraries do. SQLite is the specimen: open a database, prepare a
statement, step it, read a column, finalize, close — the whole arc, through slots, with the handles
owned and released by declaration. A fixture can then cover the parts a real library will not
reproduce on demand: a slot left unwritten, a slot of each admitted kind, and a released handle used
again.

## Referenced by

[[ADR-0018 Calling a Library Written Elsewhere]] · [[Foreign Crossing]] · [[Foreign Ownership]] ·
[[grammar/pudu]]
