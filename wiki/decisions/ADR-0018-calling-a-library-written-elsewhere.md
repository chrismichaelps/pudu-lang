---
type: decision
status: ACCEPTED
date: 2026-09-03
tags: [decision, language, ffi, foreign, unsafe]
aliases: [ADR-0018-calling-a-library-written-elsewhere]
---

# ADR-0018: Calling a Library Written Elsewhere

## Context

Everything this language can do, it does because somebody wrote it here. That is a good property for
a standard library and an impossible one for an ecosystem: the work of decades sits in shared
libraries written in C, and a language that cannot call them asks every program to re-do that work
or go without. Drawing a window, decoding a video, talking to a device — none of these are things
worth writing again, and none are reachable now.

The groundwork was laid and the decision deliberately deferred. `foreign` is already one of the four
capabilities `unsafe` grants; `null` is already permitted only inside a foreign boundary and must
become an `Option` before leaving it; and the standard library records `Std.Ffi` as open, naming the
two questions that had to be settled first — the capability, and *how a foreign type's ownership is
described*. The grammar says outright that the syntax "will be finalized before the FFI slice".

This settles it.

## What was verified before deciding

Not designed on the assumption it would work. A library is opened by name at run time, a symbol
found in it, and a call made through a signature assembled at run time — proven against the C
library every machine has, calling `strlen` and `abs` and getting 6 and 42. The mechanism is real,
so the decision below is about what to expose rather than about what is possible.

## Decision

**A foreign library is declared in a block, and the block names the library once.**

```pudu
foreign "raylib" version "5" {
  fn InitWindow(width: Int32, height: Int32, title: Str) -> ()
  fn WindowShouldClose() -> Bool
  fn BeginDrawing() -> ()
  fn EndDrawing() -> ()
  fn CloseWindow() -> ()
}
```

A block rather than an annotation on each function, because the library is the thing they share: it
is opened once, its version is one fact, and a reader asking "what does this program reach outside
itself" wants one place to look rather than a search. The declared name is what the platform is
asked for, not a path — a path is a claim about somebody else's machine, which this library has
refused everywhere else.

**The name used by Pudu and the symbol exported by the library may be stated separately.** A
declaration normally uses its local name as the symbol. When another ecosystem's naming convention
cannot be a Pudu value name, `symbol "ExactForeignName"` records the exact lookup without weakening
Pudu's naming rules:

```pudu
fn memAlloc symbol "MemAlloc"(size: UInt32) -> owned Allocation by memFree
fn memFree symbol "MemFree"(memory: Allocation) -> ()
```

Calls, releases, completion, hover, and definitions use the local names. Only the dynamic-loader
lookup uses the symbol string. An empty symbol is refused at the declaration because no C ABI can
export a useful unnamed function.

**The types that may cross are a stated, small set, and they are this language's own types.** The
integer widths, the two floating widths, a boolean, text, and nothing. `Int32` is already a type
here, not a spelling invented for the boundary, so a foreign signature is an ordinary signature: it
is checked by the ordinary checker, shown by the ordinary hover, and a caller passing the wrong
width is told so the same way as anywhere else. Every binding language that invents its own parallel
set of width names ends up spreading them through the code that calls the binding. What is not on
that list does not cross. A general marshaller for arbitrary types is how an interface becomes
unable to say what it does, and every value it fails on fails at run time.

**The C library is named rather than filed.** `foreign "c"` resolves to the running program's own
symbols, because every platform links the C library and every platform files it under a different
name — `libc.so.6` here, `libSystem.B.dylib` there, and in one common case a linker script rather
than a library at all. Nearly every language's C bindings carry a table of those names and work on
the machines the table knew about. Asking the program for its own symbols is correct everywhere and
costs nothing.

**Ownership is part of the declaration, and that is the question the standard library left open.**
The block declares each opaque handle type before a signature names it:

```pudu
foreign "raylib" {
  type Texture
  fn LoadTexture(path: Str) -> owned Texture by UnloadTexture
  fn UnloadTexture(texture: Texture) -> ()
  fn GetFrameTime() -> Float32
}
```

`owned … by …` names the function that releases it. The release takes exactly that handle and
returns nothing. The checker therefore distinguishes a `Texture` from every other address-shaped
value, while the runtime records each live address and refuses null results, use after release,
release of an unowned address, and a second release before foreign code runs. A native call leases
each handle for its full duration, so a concurrent release cannot destroy an address while native
code uses it. Each evaluator run owns a separate resource store and invokes the declared native
release for every still-live handle on success, early return, or runtime failure. A handle result
without `owned` remains refused until borrowed lifetimes have a representation; calling it
"borrowed" without being able to bound that borrow would be a promise the implementation cannot
keep. The alternative — every foreign pointer looking alike and a comment saying which must be
freed — is how every C binding leaks.

**Calling one requires `unsafe` and the `foreign` capability**, which the language already has. The
declaration is an assertion by whoever wrote it that the signature matches the library, and nothing
can check that assertion: a wrong width or a missing argument is not a diagnostic, it is a corrupted
stack. `unsafe` is where the language already says "this is asserted rather than proved", and
foreign declarations belong inside that boundary rather than beside it.

**Nothing is implicitly converted.** Text does not silently become a C string, an integer does not
silently narrow. The boundary is where a mistake is expensive, so it is the last place to guess at
what somebody meant.

## What crosses, exactly

The mapping is stated rather than inferred, and the widths are explicit. C's own `int` is not a
width — it is thirty-two bits nearly everywhere and that is a habit rather than a promise — so a
declaration names `Int32` and never `Int`. The same for `size_t`, `long`, and an enum, each of which
is a different size on some machine somebody runs.

| Declared | What crosses | Notes |
|---|---|---|
| `Int8` `Int16` `Int32` `Int64` `UInt8` `UInt16` `UInt32` `UInt64` | the integer of that exact width | never a C `int`; the width is the declaration's job, and a value that does not fit is refused rather than wrapped |
| `Float32` `Float64` | the two floating widths | placed in their own registers, which is the case a boundary assembled by hand gets wrong first |
| `Bool` | one byte, zero or not | C's `_Bool`; a C++ `bool` matches on the platforms this targets |
| `Str` | a pointer to UTF-8 bytes ending in a nought | copied both ways: for the call and freed after on the way out, and out of the library's own storage on the way back, so whose buffer it was stops mattering the moment it arrives. Text containing a nought is refused, since the other side would read less than the text says. A nought address or invalid UTF-8 where text was declared is refused rather than read through or replaced |
| a record of the scalar and text crossings above | by value, in the order its declaration writes the fields | one level and at most 32 fields; `()` is not a field; where each field sits inside it is asked of the platform, not calculated here |
| `()` | nothing | a function returning nothing |
| a block-local opaque type | one owned address | nominal, non-null, and released only by the declared function |

**An opaque owned handle is on this list; an arbitrary pointer is not.** A handle is declared by
`type Name` inside its foreign block, crosses as one machine address, cannot be inspected, and is
not interchangeable with a handle of another declared name. Its spelling in the foreign signature
must be unqualified; `Other.Name` is another module's nominal type and is refused even when this
block declares the same basename. `Ptr[T]`, borrowed handles, nullable
pointers, and records crossing by value remain later slices because each needs a lifetime, absence,
or layout rule that an opaque owned address does not.

Everything else is refused at the declaration, which is the point of stating the list: a type that
cannot cross is a diagnostic where it is written rather than a fault when it is called.

A foreign function has at most 32 arguments. That is the bounded capacity of the native bridge and
therefore part of what a declaration may say, not a late error reachable only when a large function
is called. `()` is likewise only a result shape: there is no void value to place in an argument or a
record field.

**A pointer that may be absent will say so.** C has one representation for "no answer" and "the
answer is address zero", and a declaration that does not distinguish them turns the first into a
crash on the next use. `Opt[Ptr[T]]` is how a nought will be admitted, becoming `None` before it
leaves the boundary — which is what the language already requires of `null`.

## On C++ specifically, which is not the same question

A library written in C is callable. A library written in C++ is not, and saying otherwise would be
a comfortable lie:

- **Its symbol names are not its function names.** A C++ compiler encodes the parameter types into
  the symbol, so `Shape::area(int)` is not findable under any name a person would write, and the
  encoding differs between compilers. Nothing here guesses at one.
- **A method needs an object, and an object needs a layout** — which is decided by the compiler that
  built it, including where its virtual table sits.
- **A template has no symbol until something instantiates it**, so a header full of them exports
  nothing to find.
- **An exception crossing this boundary is undefined**, not merely unsupported.

What is callable is the C-compatible surface a C++ library chooses to present — the part declared
`extern "C"`, whose names are its names and whose arguments are plain values. Every language that
calls into C++ does this, and the ones that appear not to are generating that surface for you.

So: raylib is a C library and is reachable as it stands. A C++ library is reachable through the
surface it exports for the purpose, or through a small C file somebody writes to present one. That
is the honest position, and it is better to say it than to ship something that works for the first
example and fails on the second.

## What the editor must know

A declaration is the only description of a foreign function that exists — there is no body to read
and no definition to jump to elsewhere — which makes it more important here than for ordinary code,
not less:

- **Its signature is what hover shows**, and hover says it is foreign, naming the library and saying
  the type is asserted rather than proved. A reader looking at a call
  should learn from the editor that the type is asserted rather than proved, because that is the
  thing that decides how carefully they check it.
- **Completion offers the names in the block**, with their signatures, since nothing else in the
  program mentions them.
- **Going to the definition goes to the declaration.** It is the definition, as far as this program
  is concerned.
- **The declaration carries its own diagnostics**: a type that cannot cross, a handle result without
  ownership, an owned non-handle result, an owned result that names no release, an absent release,
  or a release whose one parameter is not the handle it frees. Each is caught where it is written
  rather than where it is called.

Because the declaration is checked and typed like any other signature, all of this falls out of the
existing machinery rather than needing a second one — which is the argument for putting it in the
source rather than in a file beside it.

## Consequences

A program can reach the libraries that already exist, and the reach is visible: every foreign block
is a list of exactly what a program touches outside itself, in one place, with the library it comes
from and the version it expects.

The costs, stated plainly. A wrong declaration is a crash rather than an error, and no amount of
design changes that — it is why the whole feature sits inside `unsafe`. A program using foreign
libraries is no longer portable by construction; it is portable where those libraries are. And the
runtime gains a dependency on the machine's dynamic linker, which is the thing that makes any of
this possible and cannot be avoided while remaining useful.

## What this does not decide

**Callbacks into this language from a foreign library** are not settled here. A library that calls
back — which includes most event loops — needs a function pointer that re-enters the evaluator, with
its own answers about which thread runs it and what happens when it fails. That is a separate
decision and a separate slice.

**Which thread a call runs on** is not settled. Several libraries worth calling, graphics among
them, require the thread the program started on, and this language's workers do not currently
promise that.

**Where a library comes from** is resolved by the platform for now. Naming a version is admitted and
recorded, but nothing here fetches, pins, or verifies a library — that is the package question, and
[[architecture/PACKAGES]] says why half of that is worse than none of it.

## Alternatives Rejected

**Generating bindings from C headers.** Attractive and wrong for the first slice: it needs a C
parser, and it turns a declaration a reader can check by eye into a generated file nobody reads. A
generator can be written later over a declaration form; a declaration form cannot be recovered from
a generator.

**A binding described in a data file rather than in source.** Rejected: then the signature is not
where the calls are, the checker cannot see it, and a rename in one place is a run-time failure in
the other.

**Making foreign calls ordinary rather than `unsafe`.** Rejected. The signature is an unverifiable
assertion; the language already has a word for that, and using it costs one line per boundary.

## Validation

The mechanism was verified against a library present on every machine before any of the above was
built on it, and the first slice is checked by a program that calls it: text crossing as bytes
ending in a nought, a narrow integer and a wide one reaching different symbols, doubles arriving in
their own registers, and a mixture of the classes — which is the case a boundary assembled by hand
gets wrong first, because arguments of different classes are placed by different rules and one
counted into the wrong place arrives as whatever was already there.

The opaque-handle slice is checked against a small C++ implementation exported through
`extern "C"`: construction, typed use, release, null-result refusal, and double-release refusal all
cross the same libffi boundary as an installed library. The declaration's own failures and the
editor's inferred signatures and foreign provenance are checked alongside it.

A second integration check calls an installed Raylib 6 shared library without creating a window.
`getRandomValue(7, 7)` mapped to `GetRandomValue` proves a scalar call against a third-party C ABI,
while `memAlloc` mapped to `MemAlloc`, returning an `owned Allocation by memFree`, and the subsequent release prove that the same opaque-handle path
works with a real ecosystem library rather than only the repository fixture. The workflow pins the
Raylib source commit and builds a shared library. It runs on FFI-affecting pull requests as well as
on a schedule and manual dispatch, but remains separate from the deterministic suite because
downloading and compiling somebody else's release is interoperability evidence, not a unit-test
dependency.

## Referenced by

[[architecture/STDLIB]] · [[grammar/pudu]] · [[Unsafe Capabilities]] · [[architecture/PACKAGES]]
