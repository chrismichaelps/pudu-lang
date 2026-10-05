---
type: module
path: "@root/test/Pudu/Derive/CacheSpec.hs"
fidelity: Active
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, cache, tests]
aliases: [Derive Cache Spec]
---

# Derive Cache Spec

## Purpose and interface

`deriveCacheProperties` tests observable compile-time interface content, import
closure and actual warm-cache constant execution. These do not claim generated
derive request execution before graph elaboration is wired.

## Evidence and invariants

Store parsed frontends through the real collecting cache and compare interface
keys: derive bodies, private constants, local macros and marked helper bodies
invalidate; source relocation preserves an interface key; ordinary runtime body
edits preserve their body-free interface key. Import-closure cases cover diamonds,
cycles, absent modules, unused runtime branches and derive/constant roots.

A complete temporary program folds a transitive ordinary helper call into a
consumer constant. Cold/warm runs agree, and a same-length/same-timestamp helper
body edit changes the warm result to the exact fresh result. Check diagnostics,
frozen values and actual execution through the compiler's normal cache boundary.

## Grill Log

- **Q:** Test only hash inequality? **A:** Also execute a warm cached consumer
  whose frozen answer must change. _Rejected:_ missing the actual stale-product bug.
- **Q:** Assume comptime flags inventory all folding? **A:** Use an ordinary
  imported function through another ordinary helper. _Rejected:_ a marker-only
  test that ignores existing constant-folding semantics.
- **Q:** Promise position-free graph keys? **A:** Assert that only interface keys
  are position-free; source closure relocation may safely miss.

## Linkage and references

Requires [[Compiler Cache]], [[Compiler Program]], [[Compile-Time Dependency Closure]]
and [[Eval Program]]. Referenced by [[src/_MOC]] · [[Repository Test Runner]] ·
[[Pudu Test Cabal Manifest]].
