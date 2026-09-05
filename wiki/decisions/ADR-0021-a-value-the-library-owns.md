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
all** — `Color`, `Rectangle`, `Vector2`, `Vector3`, `Matrix`, `Camera2D`, `Camera3D`, `Ray`,
`BoundingBox` and their kind. Those have crossed since a record was allowed to hold a record. A
declaration naming them checks today:

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
  owned type Image = (Ptr, Int32, Int32, Int32, Int32) by unloadImage

  fn loadImage symbol "LoadImage" (path: Str) -> Image
  fn unloadImage symbol "UnloadImage" (image: Image) -> ()
  fn imageWidth symbol "GetImageWidth" (image: Image) -> Int32
}
```

Four things follow.

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

**It is owned, and ownership works as it already does.** `by unloadImage` names the function that
frees it, under the rules a handle result already follows: the release takes exactly that type and
returns unit, and it is declared in the same block. The store leases the value for the duration of a
call, refuses a second release, refuses use after release, and releases at teardown what the program
did not. The one difference from a handle is what identity means, and it is the next point.

**Two of them are the same resource when their addresses agree.** A handle is an address, so identity
is the address. A value like this is several scalars, one or more of which is an address, and the
library will hand the same underlying resource back as two bit-identical copies without expecting two
releases. Identity is therefore the addresses inside the layout, in order: two values whose pointer
scalars all agree are one resource, and releasing either releases it. A layout holding no address at
all is refused — it would be an ordinary record, and a record is what it should be declared as.

## What This Does Not Decide

**Reading a field.** Deliberately never, for the reason above; a library that offers no accessor for
something a program needs is a library that has to be asked for one.

**Building one.** A value of this kind arrives from the library and returns to it. A program cannot
construct one, and there is no literal for it.

**A pointer as an ordinary type.** `Ptr` stays inside a layout. Admitting it as a value would make an
address an integer, which every part of this boundary has refused.

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

## Amendment 2026-09-04: the identity rule is wrong, and blocks acceptance

Checked against `raylib.h` as installed, three structs a library releases by value hold no pointer at
any depth: `Texture` (`unsigned int id` and four `int`s, freed by `UnloadTexture`), `RenderTexture`
(freed by `UnloadRenderTexture`), and `VrStereoConfig`. `Texture2D` is among the most used types the
library has.

That falsifies two statements above.

**"A layout holding no address at all is refused — a record is what it should be declared as."** A
`Texture2D` declared as an ordinary record is a resource nothing owns: a program may copy it freely
and call `UnloadTexture` on both copies, and no part of this design would say a word. The sentence
counting 20 pointer-free structs as values that "have crossed since a record was allowed to hold a
record" silently includes two resources among them.

**"Identity is therefore the addresses inside the layout, in order."** A `Texture`'s identity is its
`id`, an integer. A rule keyed on addresses cannot express it, and a rule that refuses pointer-free
layouts cannot even reach it.

The error is inference. Which scalars happen to be pointers is a fact about how the platform places
the value in registers or memory, and the design already needs it for exactly that. It carries no
information about what the library considers one resource, and reusing it as identity conflates a
calling-convention question with an ownership question that only the declaration can answer.

**Decided: identity is declared, never inferred.** A declaration names the scalars that identify the
resource, the layout continues to name the scalars the value is made of, and neither reads the other.
A pointer-free layout is admitted as an owned value. `owned`/`by` and the store's rules are unchanged;
only where identity comes from changes. This ADR stays PROPOSED until it is rewritten on that basis —
implementing the rule as written would put a wrong ownership model under 220 of the 600 functions.

Still unresolved, and not to be papered over: a library that hands the same identity back twice and
expects two releases — a retain/release count — cannot be modelled by merging equal identities at all.
Until there is a transfer contract that can say so, such a binding needs a C wrapper returning an
opaque handle, which [[ADR-0018-calling-a-library-written-elsewhere]] already supports.

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
- A pointer-free layout that a library releases by value — `Texture2D` is the case to use — is owned,
  and a second release of it is refused.
- The pointer-free raylib structs that no `Unload` takes keep crossing as ordinary records.

## Referenced by

[[ADR-0018-calling-a-library-written-elsewhere]] · [[ADR-0019-getting-a-value-back-out-of-a-library]]
· [[ADR-0020-handing-a-library-a-run-of-bytes]] · [[grammar/pudu]] · [[Foreign Crossing]]
