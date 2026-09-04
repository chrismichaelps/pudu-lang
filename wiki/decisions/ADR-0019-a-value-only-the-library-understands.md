---
type: decision
status: PROPOSED
date: 2026-09-04
tags: [decision, language, ffi, foreign, unsafe]
aliases: [ADR-0019-a-value-only-the-library-understands]
---

# ADR-0019: A Value Only the Library Understands

## Context

[[ADR-0018 Calling a Library Written Elsewhere]] settled how a program reaches a library, and what
has been built on it reaches a good deal: scalars at stated widths, text as UTF-8, records by value
including records of records, and opaque handles whose release is named in the declaration and
checked before it runs.

Measured against raylib, which is a fair specimen of the kind of library worth reaching for, that is
288 of 548 functions. The remaining 260 were treated as one problem — "pointers" — and they are not.
Counting what each missing shape blocks on its own:

| Functions blocked by exactly this | Shape |
|---|---|
| 196 | a struct the library owns, returned **by value**, holding a pointer inside |
| 9 | a contiguous buffer: `Vector2*`, `Color*`, `unsigned char*` |
| 7 | a callback |
| 6 | a scalar out-parameter: `int*`, `float*` |
| 3 | a flat struct passed by reference |

One shape is three quarters of what is left, and it is not the shape the earlier guess named. A
scalar out-parameter unlocks six functions. The thing worth deciding is the first row.

## What the first row actually is

`LoadImage` hands back an `Image`. An `Image` is a struct — returned by value, on the stack, not
through a pointer — and one of its fields is a pointer to pixels the library allocated:

```c
typedef struct Image {
    void *data;
    int width, height, mipmaps, format;
} Image;

RLAPI Image LoadImage(const char *fileName);
RLAPI void ImageResize(Image *image, int newWidth, int newHeight);
RLAPI void UnloadImage(Image image);
```

A program holds that value, hands it back to functions that read or change it, and eventually gives
it to `UnloadImage`. `Font`, `Sound`, `Music`, `Mesh`, `Shader`, `Model` and `Wave` are all this
shape. It is the ordinary way a C library gives a program a resource.

Neither thing already built covers it. It is not a record crossing by value, because a field of it is
a pointer and nothing here can say what that pointer means. It is not an opaque handle, because a
handle **is** an address and this is a value that merely contains one.

## Decision

**A program may hold a value it cannot read, and the declaration says how big it is.**

```pudu
foreign "raylib" version "6" {
  opaque Image = { Ptr, Int32, Int32, Int32, Int32 }

  fn loadImage symbol "LoadImage" (path: Str) -> owned Image by unloadImage
  fn unloadImage symbol "UnloadImage" (image: Image) -> ()
  fn imageWidth symbol "GetImageWidth" (image: Image) -> Int32
}
```

An `opaque` declaration names the shape without naming any meaning. The field list is not fields: it
is the sequence of machine kinds the platform needs in order to place the value in registers or on
the stack. `Ptr` is admitted **only** here, where nothing can read through it.

Four things follow, and each is the reason for the one before it.

**The layout must be written, because a black box cannot be passed by value.** Handing a struct to a
library is not handing it N bytes: a struct of two floats and a struct of eight bytes go to different
places under the same size. The calling convention classifies by the sequence of scalar kinds, so
that sequence is what the declaration has to carry. A binding author reads the header once and writes
it down. That is a real cost and it is the honest one — the alternative is guessing at a
classification, and a wrong guess is not a diagnostic.

**A program may not read it, and nothing offers to.** The value has no fields in Pudu. There is no
accessor, no pattern, no printing beyond a name. Everything a program wants to know about it, it asks
the library — `GetImageWidth`, not `image.width`. Admitting a reader would mean the declaration's
field list had meanings, and the moment it has meanings a wrong one is a silent misreading rather
than a refusal.

**It is owned exactly as a handle is.** `owned Image by unloadImage` puts the release in the
declaration; the store leases it for the duration of a call, refuses a second release, refuses use
after release, and runs the declared release at teardown for anything still held. None of that is new
work — it is the machinery [[Foreign Ownership]] already has, pointed at a value rather than an
address.

**A borrowed one stays refused.** `-> Image` without `owned … by …` is refused where it is written,
as `-> Handle` already is. Whether a library expects the caller to free a returned value is not
something a signature can be read off, and the failure of guessing wrong is a leak in one direction
and a double free in the other.

## What this does not decide

**A pointer as an ordinary type.** `Ptr` is admitted inside an `opaque` layout and nowhere else. A
program still cannot hold one, pass one, or read through one. That restriction is what keeps the
whole feature checkable: the only thing that ever holds a pointer is a value the program cannot open.

**In-out parameters.** `ImageResize(Image *image, ...)` takes the address of a value the caller
holds, and writes through it. That is 48 of the 196 and it needs its own answer, because a value
being written to while the program holds it is a different question from a value being passed. The
first slice covers by-value arguments and by-value results; `Image*` waits.

**Contiguous buffers, scalar out-parameters, and callbacks** — 22 functions between them, each with
its own lifetime question, and none of them urgent at that size.

## Alternatives Rejected

**Treat it as an opaque handle by taking its address.** Rejected: the library returns it by value.
There is no address to take that outlives the call, and inventing one means allocating a copy whose
lifetime nothing describes.

**Let the declaration name the fields properly and read them.** Rejected, and it is the tempting one.
`Image` really does have a width, and a program really does want it. But the fields a header shows
are not a contract — a library may reorder them between versions where the functions stay — and a
program that read `image.width` directly would be right until the day it silently was not.
`GetImageWidth` is the library's answer to that question and it stays correct.

**Infer the layout from the header.** Rejected for the first slice, for the reason
[[ADR-0018 Calling a Library Written Elsewhere]] gave for rejecting generated bindings: it needs a C
parser, and it turns a declaration a reader can check by eye into a generated file nobody reads. A
generator can be written later over this declaration form; the form cannot be recovered from a
generator.

**Do the smaller shapes first.** Rejected on the measurement. Scalar out-parameters unlock six
functions and buffers nine. Doing them first would be choosing the easy work over the work that
matters, and the ordering was only ever plausible because nobody had counted.

## Validation

The mechanism is already proven in part: a struct crossing by value in both directions was measured
against a C++ surface before records were admitted, including one whose fields need padding between
them. What this adds is a layout the program does not interpret, so the checks are that a declared
layout matches what the platform computes for the real struct, that a value survives being handed
back to the library that made it, that a program cannot read one, and that the ownership rules a
handle already has hold here unchanged.

The first proof should be against a real installed library rather than only a fixture, because the
whole point of the shape is what real libraries do with it.

## Referenced by

[[ADR-0018 Calling a Library Written Elsewhere]] · [[Foreign Crossing]] · [[Foreign Ownership]] ·
[[grammar/pudu]]
