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
  fn InitWindow(width: I32, height: I32, title: CText) -> ()
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

**The types that may cross are a stated, small set.** The integer widths, the two floating widths,
a boolean, text as the C representation, an opaque pointer, and a record whose fields are themselves
crossable. What is not on that list does not cross. A general marshaller for arbitrary types is how
an interface becomes unable to say what it does, and every value it fails on fails at run time.

**Ownership is part of the declaration, and that is the question the standard library left open.**
A pointer a foreign library hands back is one of two things, and the declaration says which:

```pudu
foreign "raylib" {
  fn LoadTexture(path: CText) -> owned Texture by UnloadTexture
  fn GetFrameTime() -> F32
}
```

`owned … by …` names the function that releases it. So an owned value carries what frees it in its
own type, a program that drops one without releasing it is something a checker can see, and
releasing one twice is refused rather than being a fault the operating system reports much later.
A pointer without `owned` is borrowed: valid for the call that produced it and not to be kept. The
alternative — every foreign pointer looking alike and a comment saying which must be freed — is how
every C binding leaks.

**Calling one requires `unsafe` and the `foreign` capability**, which the language already has. The
declaration is an assertion by whoever wrote it that the signature matches the library, and nothing
can check that assertion: a wrong width or a missing argument is not a diagnostic, it is a corrupted
stack. `unsafe` is where the language already says "this is asserted rather than proved", and
foreign declarations belong inside that boundary rather than beside it.

**Nothing is implicitly converted.** Text does not silently become a C string, an integer does not
silently narrow. The boundary is where a mistake is expensive, so it is the last place to guess at
what somebody meant.

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

The mechanism is verified against a library present on every machine before any of the above is
built on it. Each slice adds its own checks: that a declaration's types are the ones admitted, that
a call outside `unsafe` is refused, that an owned value names its release, and that releasing one
twice is refused.

## Referenced by

[[architecture/STDLIB]] · [[grammar/pudu]] · [[Unsafe Capabilities]] · [[architecture/PACKAGES]]
