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

## Internal collection kernel integration

[[Runtime Collection Kernels]] owns reusable pure storage construction/enumeration; evaluator adapters supply value projections. The module is registered in the compiler library.

### Resolved Grill Log
- **Q:** Duplicate storage loops in each value adapter? **A:** No; share the internal generic kernel without changing public STD behavior.

## Word-map cardinality kernel

`wordMapPopCount[K](Map[K, UInt64]) -> UInt128` is a pure wired-in reduction consumed by
[[Std BitSet]]. It counts payload bits independently of keys, including zero payloads, and avoids
entry-array materialization. The runtime checks UInt64 kind/range before conversion and reports
E7001 for invalid payloads or receiver, E7003 for wrong arity. Registration covers semantic names,
type signatures, installation, builtin naming and pure dispatch. No IO or FFI capability is required.

Resolved Grill Log: Use an explicit primitive rather than recognize a library function by name,
so shadowing and ordinary calls retain their meaning. Result width is UInt128; an Int-sized host
map cannot contain enough 64-bit words to overflow it. This remains unvalidated.

## Buffer and SwissTable runtime integration

Registers [[Runtime Buffer Kernels]], [[Eval Buffer]], [[Runtime SwissTable Kernels]], and [[Eval SwissTable]]
in `pudu.cabal` library exposed-modules.

### Resolved Grill Log
- **Q:** Rely on dynamic reflection or untyped FFI for low-level memory operations? **A:** No; register explicit Haskell modules with checked boundaries.

## Columnar runtime integration

Registers [[Pudu/Runtime/Column]] and [[Pudu/Eval/Column]] in `pudu.cabal` library exposed-modules for vectorized columnar aggregations and filtering.

### Resolved Grill Log
- **Q:** Implement columnar operations through dynamic interpreted loops? **A:** No; expose compiled native Haskell runtime kernels and evaluator primitives with strict bounds validation.




## TLS and binary compression implementation contract

Registers Pudu.Eval.Compress and pins zlib >=0.7.1 && <0.8. The adapter uses the documented incremental API of zlib 0.7.1.0.

Resolved Grill Log: protocol bytes must remain bytes; verified transport cannot downgrade. Errors remain explicit and resource ownership transfers once. Implementation is code-only; no validation or readiness claim.


## Evaluation lifecycle modules

Register Pudu.Eval.Runtime and Pudu.Eval.Context. Resolved Grill Log: one-shot and persistent evaluation share the same resource owner, with no new package dependency.
