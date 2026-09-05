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
those in [[grammar/haskell]].

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
