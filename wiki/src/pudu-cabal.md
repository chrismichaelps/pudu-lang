---
type: module
path: "@root/packages/pudu/v0.1/pudu.cabal"
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
`Std/Audio/*.pudu` and `Std/Ui/*.pudu` are both source-distribution data, including their nested
modules. The macOS desktop adapter and Cocoa/CoreGraphics framework linkage are conditional on
`os(osx)`; other targets compile the typed unsupported implementation in [[Eval Desktop]].
The framework-neutral desktop header is an explicit source-distribution input.
The framework-neutral audio header is likewise distributed explicitly. On macOS the private audio
adapter and AudioToolbox linkage are conditional on `os(osx)`; other targets compile [[Eval Audio
Device]] with a stable unsupported result and no Apple headers.

The production `pudu` package contains the compiler library and executable only. Repository tests
belong to [[Pudu Test Cabal Manifest]], a sibling package rooted where `test/` and `test-fixtures/`
actually live. No component may escape this package through `..`: Cabal source archives reject such
links, which made a clean `cabal install exe:pudu` fail even though in-tree builds worked.

## Grill Log

- **Q:** Leave an extracted runtime module outside the library module list? **A:** No. Registration
  keeps source distributions and builds aware of the implementation dependency.
- **Q:** Add a dependency for ownership cleanup? **A:** No; the existing base, STM, containers, and
  text dependencies supply the required primitives.
- **Q:** Link Apple frameworks on every target? **A:** No; target-only linkage belongs under Cabal's
  operating-system condition. The public Pudu module remains present and reports unsupported where
  no presenter exists.
- **Q:** Keep the root test tree as `../../../test` in this package? **A:** No. _Rationale:_ Cabal
  emits an unsafe archive link and refuses to reinstall the compiler. _Accepted:_ a separate root
  test package in the same project, preserving `cabal test all` without copying sources.
- **Q:** Put AudioToolbox types in the Haskell FFI declaration? **A:** No. _Rationale:_ the stable C
  ABI uses fixed-width scalars and bytes only. _Accepted:_ link the target framework only where its
  adapter is compiled.

## Referenced by

[[src/_MOC]] · [[Eval Foreign Resource]] · [[Eval Foreign Result]] · [[Eval Desktop]] ·
[[Pudu Test Cabal Manifest]] · [[Pudu Cabal Project]]

## Bounded device-audio adapter

Register [[Eval Audio Device]], distribute [[Pudu Audio Header]], and compile [[Pudu Audio Adapter]]
only on macOS with AudioToolbox. Resolved Grill Log: the public module exists on every target while
native source and framework linkage remain target-conditional.

Register [[Eval Audio Kernel]] as a portable Haskell module with no new package or native-library
dependency. Resolved Grill Log: acceleration of pure sample arithmetic is cross-platform and must not
be hidden under the macOS adapter condition.

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

## REPL execution adapter

Register Pudu.Repl.Evaluation. Resolved Grill Log: checked entry selection and
compatibility guards live outside the terminal loop and source assembly module.

## Version enforcement and bundle execution

Register Pudu.Version in library exposed-modules for Cabal-derived package versioning. Add temporary >=1.3 && <1.4 dependency to the pudu executable component for isolated bundle module extraction.

### Resolved Grill Log

- **Q:** Hardcode version numbers across tools? **A:** No; derive the language version and constraints directly from Cabal metadata via Pudu.Version.
- **Q:** Reuse a global bundle cache directory across runs? **A:** No; withSystemTempDirectory ensures isolated per-process extraction without collisions or left-behind artifacts.
