---
type: decision
status: PROPOSED
date: 2026-09-04
tags: [decision, language, ffi, foreign, ownership]
aliases: [ADR-0021-a-value-the-library-owns]
---

# ADR-0021: A Value the Library Owns

## Context

A record crosses by value when every field crosses, and a handle crosses when the library hands back
an address. Between them sits a shape neither covers: a struct the library passes **by value** whose
interior holds an address.

```c
typedef struct Image  { void *data; int width, height, mipmaps, format; } Image;
typedef struct Shader { unsigned int id; int *locs; } Shader;
typedef struct Font   { int baseSize, glyphCount, glyphPadding; Texture2D texture;
                        Rectangle *recs; GlyphInfo *glyphs; } Font;
```

It is not a record: a field of it is an address, and a record crosses as the scalars it flattens to.
It is not a handle: a handle **is** an address, and this merely contains one — it arrives in
registers or on the stack, not through a pointer.

## What is actually blocked

The shape has been described before as "structs returned by value", and counted at 196. Both were
wrong, and the correction narrows the problem considerably.

raylib 6 declares 600 functions and 35 by-value structs. Of those structs, **20 hold no address at
all**. Most are plain values — `Color`, `Rectangle`, `Vector2`, `Vector3`, `Matrix`, `Camera2D`,
`Camera3D`, `Ray`, `BoundingBox` — which have crossed since a record was allowed to hold a record,
and a declaration naming them checks today. Three of the twenty are not values at all: `Texture`,
`RenderTexture` and `VrStereoConfig` hold only integers and each has an `Unload*` that takes it by
value. Holding no address is not the same as owning nothing, and counting them together was the
mistake this decision was first written on.

```pudu
fn beginMode3D symbol "BeginMode3D" (camera: Camera3D) -> ()
fn drawRectangleRec symbol "DrawRectangleRec" (rec: Rectangle, color: Color) -> ()
```

**15 hold an address**, directly or through nesting: `Image`, `Shader`, `Font`, `Mesh`, `Model`,
`Material`, `ModelAnimation`, `ModelSkeleton`, `Music`, `Sound`, `Wave`, `AudioStream`, `GlyphInfo`,
`FilePathList`, `AutomationEventList`. **220 of the 600 functions touch one of them.** Another 115
use an address some other way; 265 touch neither.

Counted from the `RLAPI` declarations in the installed `raylib.h`, which is the exact figure for this
header. A survey written to read four headers with one method for comparability undercounts it, so
the numbers here are the ones to build against.

So the blocker is not breadth. It is one precise thing: **a value the library owns, which the program
holds and passes back, and must never look inside.**

## Decision

**A foreign block may declare a value type it owns, and the declaration says how large it is by
naming the scalars it is made of.**

```pudu
foreign "raylib" version "6" {
  type Image = (Ptr, Int32, Int32, Int32, Int32)
  type Font  = (Int32, Int32, Int32, UInt32, Int32, Int32, Int32, Int32, Ptr, Ptr)

  fn loadImage       symbol "LoadImage"      (path: Str)    -> owned Image by unloadImage
  fn unloadImage     symbol "UnloadImage"    (image: Image) -> ()
  fn imageWidth      symbol "GetImageWidth"  (image: Image) -> Int32

  fn getFontDefault  symbol "GetFontDefault" ()             -> borrowed Font
}
```

The type says how the value crosses. Each result says what it transfers, because the same type does
different things in different functions.

What follows.

**The layout is written, and it has no field names.** It has to be written because a value passed in
registers cannot be a black box: the platform classifies a struct by the sequence of scalar kinds it
flattens to together with its size and alignment, so a struct of two floats and a struct of eight
bytes go to different places at the same size. Guessing that is not a diagnostic, it is a corrupted
call frame. It has **no field names** because naming them would invite reading them, and what sits at
each offset is the library's business and changes between its versions while its functions do not. A
program reaches the width through `GetImageWidth`, not through `image.width`.

**`Ptr` names a scalar the size of an address, and exists only inside such a layout.** It is not a
type a program may write, hold, or compare. Its whole content is "this many bytes, classified as a
pointer", which is what the platform needs in order to place the value correctly.

**What a result transfers is declared on the result, not on the type.** One C type arrives owned from
one function and borrowed from another: raylib's `Font` comes owned from `LoadFont` and borrowed from
`GetFontDefault`, which returns the library's own copy that must never be unloaded. A `by` clause
attached to the type cannot say which, so the obligation belongs to each result:

- **owned** — the result carries one release. `LoadImage`, `H5Dopen`.
- **borrowed** — the result carries none, and the library keeps it. `GetFontDefault`. Pudu cannot
  check that the owner outlives it; what it can do is never release it.
- **counted** — the result carries its own release even when another result is bitwise identical to
  it. `cairo_reference`, `g_object_ref`.

All three are implemented for handle results as of 2026-09-04, under
[[ADR-0018-calling-a-library-written-elsewhere]]: `owned T by release`, `borrowed T`, and
`counted T by release`. That part of this decision needed nothing from the layout question below,
which is why it did not wait for it. What remains proposed here is the by-value layout: a struct the
library passes in registers, and the identity rule for one.

**Identity is declared, and never inferred from which scalars are pointers.** Which fields are
addresses tells the platform how to place the value, which the layout is written for. It says nothing
about what the library counts as one resource, and libraries disagree: HDF5 names every file, dataset
and group by an `int64_t` `hid_t`; raylib's `Texture` is five integers; an OpenGL name, a file
descriptor and a Windows `HANDLE` are all integers. A rule keyed on addresses cannot express any of
them, and a rule refusing pointer-free layouts cannot reach them.

The default is the whole value: two values equal in every scalar are one resource. A declaration may
narrow that to the scalars that identify it, for a library that varies a field it does not consider
part of the identity — raylib's `Music` carries a `looping` flag beside the context pointer that owns
the resource.

**A counted result is not merged with anything.** Two references from `g_object_ref` are bitwise
equal and each owes an unref, so identity-merging is exactly wrong for them, which is why the mode is
declared rather than derived from equality.

**The three modes are about ownership, not about how a value crosses.** They apply to a handle result
exactly as they do to a value passed by value: an opaque `cairo_t *` from `cairo_reference` is
counted, a pointer to a library's own state is borrowed, and what handles do today is the owned case
under a name. Only the layout in this decision is specific to a struct in registers. Writing the modes
as though they belonged to by-value structs alone would leave the same three questions unanswered for
the pointers a library hands back, which is most of what any library hands back.

## What This Does Not Decide

**Reading a field.** Deliberately never, for the reason above; a library that offers no accessor for
something a program needs is a library that has to be asked for one.

**Building one.** A value of this kind arrives from the library and returns to it. A program cannot
construct one, and there is no literal for it.

**A pointer as an ordinary type.** `Ptr` stays inside a layout. Admitting it as a value would make an
address an integer, which every part of this boundary has refused.

**A resource holding another resource.** A `Font` embeds a `Texture`, and `UnloadFont` frees the
atlas with it. Nothing here says whether the inner one may be named separately, released separately,
or survives its container, and a library that lends out an interior resource — `Model` holding
`Material` holding `Texture` is the same shape — needs an answer before its bindings are safe. The
conservative reading, and the one to implement first, is that only the outermost value is a resource
and an interior one is reachable through the library's own accessors.

**The other 115.** Functions using an address some other way — a run the library writes into, a run it
allocates, a callback — keep their own decisions under
[[ADR-0020-handing-a-library-a-run-of-bytes]] and what follows it.

## Alternatives Rejected

**Let a record hold a `Ptr` field.** Rejected: it makes the address readable, and then a program can
hold it after the value is released, compare it, or do arithmetic on it. The layout exists to be
described to the platform, not to be seen.

**Treat the whole struct as opaque bytes of a declared size.** Rejected: size is not enough. The
platform places a value by the classes of the scalars it flattens to, so a description that gave only
a size would put a struct of two floats where a struct of eight bytes goes, on the machine where
those differ.

**Ask the platform for the layout at run time, as record offsets already are.** Rejected: the offsets
of a struct can be asked for only once its member kinds are known, which is exactly what is missing.
The declaration is where they enter.

**Return it as a handle by having the binding allocate one.** Rejected: it means a C shim for every
such function, and the point of a foreign declaration is to call the library rather than a layer
written to make the library callable.

## Why this is not a raylib design

raylib is the evidence, not the target: a foreign boundary is worth having only if it reaches
libraries nobody had in mind when it was written. Checked on this machine, three shapes recur across
unrelated libraries and none of them are expressible by inferring ownership from pointers.

**A resource named by an integer.** HDF5 declares `typedef int64_t hid_t`, and every file, dataset,
group and dataspace it hands out is one, closed by `H5Dclose` and its siblings. raylib's `Texture`
is five integers, freed by `UnloadTexture`; `RenderTexture` and `VrStereoConfig` are the same. An
OpenGL name, a POSIX file descriptor and a Windows `HANDLE` are all integers too. The first draft of
this decision refused a pointer-free layout as "an ordinary record" — which would have made every one
of these a value nothing owns, free to copy and to close twice with nothing said.

**A resource counted rather than owned.** cairo pairs `cairo_reference` with `cairo_destroy`, GObject
pairs `g_object_ref` with `g_object_unref`, and CoreFoundation, COM and the Python C API all work
this way. Two references are bitwise equal and each owes a release. The first draft's rule — two
values whose pointers agree are one resource, and releasing either releases it — turns every second
reference into a leak, or worse, releases an object another reference is still holding.

**A resource the library keeps.** `GetFontDefault` returns raylib's own `Font`; GObject's
documentation shows `g_object_ref (the_singleton)` for the same shape. Releasing one of these is a
fault, and a design in which ownership is a property of the *type* cannot say that `LoadFont` and
`GetFontDefault` return the same type under different obligations.

Together these are why identity and transfer are declared per result. Inference from the layout was
reading a calling-convention fact — which scalars are addresses — as an ownership fact, and the two
are unrelated.

## Validation Required Before Implementation Is Complete

- A C conformance fixture passes and returns a struct holding an address beside scalars, and proves
  the value that comes back is the one that went in.
- The classification is proven where it can differ: a layout of two floats, a layout of an address
  and scalars, and a layout large enough to be returned through memory rather than registers.
- Ownership is proven as it is for handles: release once, refuse a second, refuse use after release,
  release at teardown what the program did not.
- Two copies the declaration says are one resource are one claim, and releasing either releases it
  once.
- A `Ptr` written outside a layout is refused, as is a field read through such a value.
- A pointer-free layout the library releases by value is owned and refuses a second release. Prove it
  on an integer identity, not a pointer one: raylib's `Texture2D` or an HDF5 `hid_t`.
- A borrowed result is never released, proved against a function returning the library's own value —
  `GetFontDefault` is the case to use — including at teardown.
- A counted result is not merged with an equal one: two references each release once, and the object
  outlives the first release.
- A declaration narrowing identity to part of the layout treats two values differing only outside
  that part as one resource.
- The pointer-free structs that no release takes keep crossing as ordinary records.

## Referenced by

[[ADR-0018-calling-a-library-written-elsewhere]] · [[ADR-0019-getting-a-value-back-out-of-a-library]]
· [[ADR-0020-handing-a-library-a-run-of-bytes]] · [[grammar/pudu]] · [[Foreign Crossing]]
