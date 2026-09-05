---
type: module
path: "@root/pudu.cabal"
fidelity: Active
tags: [module, build]
aliases: [Pudu Cabal Manifest]
---

# Pudu Cabal Manifest

## Purpose and interface

Declare package metadata, compiler library modules, executable components, test components, compiler
warnings, language defaults, dependencies, and native bridge linkage for the Cabal build.

## Dependencies and consumers

Cabal consumes this manifest and `cabal.project`. The library includes [[Eval Foreign Resource]] and [[Eval Foreign Result]]
alongside [[Eval Foreign]], [[Foreign Call]], and [[Foreign Ownership]]. Source module registration
must match actual Haskell module declarations. Existing dependency and toolchain policies remain
those in [[grammar/haskell]]. A test module is registered the same way: an unregistered spec compiles
nowhere and runs never, so the suite reports success without it.

## Invariants and negative logic

Do not introduce runtime behavior, implicit network setup, private governance inputs, or alternate
compiler semantics through build metadata. Every new library module must be registered explicitly.

## Grill Log

- **Q:** Leave an extracted runtime module outside the library module list? **A:** No. Registration
  keeps source distributions and builds aware of the implementation dependency.
- **Q:** Add a dependency for ownership cleanup? **A:** No; the existing base, STM, containers, and
  text dependencies supply the required primitives.

## Referenced by

[[src/_MOC]] · [[Eval Foreign Resource]] and [[Eval Foreign Result]]

## SQLite native adapter

Compile `cbits/pudu_sqlite.c` beside the libffi bridge. SQLite itself is loaded only on demand, retaining the existing POSIX dynamic-loader dependency and requiring no SQLite development headers.

### Resolved Grill Log
- **Q:** Link every compiler invocation against SQLite? **A:** No; bundle the small ABI adapter and load SQLite only when its driver connects.
