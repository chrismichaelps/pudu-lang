---
type: module
path: "@root/packages/pudu/v0.1/pudu.cabal"
fidelity: Active
tags: [module, build]
aliases: [Pudu Cabal Manifest]
---

# Pudu Cabal Manifest

Register [[Compiler Product Publication]] as the bounded cache-admission and
product-lifetime boundary. Resolved Grill Log: preserve compiler phases and
cache identity; full analysis remains available independently of executable reuse.

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

[[Type Check Derive]] and [[Type Substitution]] are explicit production modules.
The former validates signatures; the latter is a pure utility shared by ordinary
checking. Resolved Grill Log: register each module without adding dependencies.

Do not introduce runtime behavior, implicit network setup, private governance inputs, or alternate
compiler semantics through build metadata. Every new library module must be registered explicitly.
`Std/Audio/*.pudu` and `Std/Ui/*.pudu` are both source-distribution data, including their nested
modules. The macOS desktop adapter and Cocoa/CoreGraphics framework linkage are conditional on
`os(osx)`; other targets compile the typed unsupported implementation in [[Eval Desktop]].
The framework-neutral desktop header is an explicit source-distribution input.
The framework-neutral audio header is likewise distributed explicitly. On macOS the private audio
adapter and AudioToolbox linkage are conditional on `os(osx)`; other targets compile [[Eval Audio
Device]] with a stable unsupported result and no Apple headers.

[[Pudu CLI Init]] is a compiler-library module so both the executable and repository tests exercise
one initialization contract. Its filesystem and text needs are already production dependencies; no
new runtime package is introduced.

[[Pudu Lint]], [[Pudu Lint Config]], and [[Pudu CLI Lint]] are compiler-library modules. They reuse existing syntax,
typing, diagnostic, JSON, directory, text, and filepath dependencies; linting introduces no foreign
tool, plugin runtime, or package dependency.

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
- **Q:** Keep project initialization private inside the executable entry point? **A:** No.
  _Rationale:_ then filesystem safety can only be tested by spawning a separately located binary,
  and the command dispatcher retains another responsibility. _Accepted:_ one focused library module
  consumed by the thin CLI and its tests.

## Referenced by

[[src/_MOC]] · [[Eval Foreign Resource]] · [[Eval Foreign Result]] · [[Eval Desktop]] ·
[[Pudu Test Cabal Manifest]] · [[Pudu Cabal Project]]

## Bounded device-audio adapter

Register [[Eval Audio Device]] and [[Eval Audio Stream]], distribute [[Pudu Audio Header]] plus
[[Pudu Audio Stream Header]], and compile [[Pudu Audio Adapter]] plus [[Pudu Audio Stream Adapter]]
only on macOS with AudioToolbox. Resolved Grill Log: the public modules exist on every target while
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

## Reading numbers from text (#349)

Registers `Pudu.Eval.Builtin.TextNumber` in the library's exposed modules; no new dependency.

## Source digest (#352)

Registers `Pudu.Version.Digest` and adds `template-haskell` (a GHC boot package) to the library so
the digest is computed while the compiler is compiled.

## Native checksums (#343)

Registers `Pudu.Eval.Checksum` in the library's exposed modules; it needs no new dependency.

## Runtime packs (#355)

Registers `Pudu.Cli.RuntimePack`; it uses the already-linked `zlib` and the package HTTP client.

## Alias dependency ordering (#372)

Register [[Type Formation Order]] as a library module. Resolved Grill Log: transparent aliases
are formed in dependency order before record/sum fields, with deterministic cycles left for
existing formation diagnostics; no new package is required.

## Imported constant dependencies (#373)

Register [[Compiler Constants]] for transitive checked dependency selection. Resolved Grill Log:
selection is bounded and cycle-safe, and folds use existing dependency products without new IO.

## Fused MultiMap operations

The pure primitives `multiMapAdd[K, V](&Std.MultiMap.MultiMap[K, V], K, V)` and
`multiMapContains[K, V](&Std.MultiMap.MultiMap[K, V], K, V)` preserve the library's
record shape and ordered maps. [[Eval MultiMap]] owns their runtime implementation.
`add` appends to the group and increments its occurrence count with one tree traversal
per map; `contains` performs one occurrence lookup. They are registered by name,
typed with the canonical library nominal identity, installed, and dispatched as pure
builtins, so aliases, first-class wrappers, shadowing, and constant folding retain
ordinary call semantics.

Resolved Grill Log: use explicit primitives rather than recognizing a library function
by name. Preserve persistence, key representatives, duplicate counts, checked Int
overflow, and E7008 for unorderable keys or values. Do not scan complete maps on every add.

Register Eval.MultiMap.Kernel for the bounded pure MultiMap loop intrinsic and
Eval.Foreign.Binding for unchanged foreign metadata extracted from Eval.Value.
Resolved Grill Log: both are runtime implementation modules; no dependency or
public Pudu package interface changes.

Register Eval.Call.Argument and Eval.Call.Needs for the pre-existing call helper
extraction included in the complete pending-work delivery.

## Derive resolution hardening

Register Resolve.Reflection and Resolve.Bindings. Resolved Grill Log: pure
import classification and the existing pattern walk require no new dependencies.

Register [[Type Check Reflection]] and [[Type Check Receiver]]. Resolved Grill
Log: typed descriptors and receiver specialization reuse existing checker and
canonical type primitives without introducing dependencies.

## Derive record expansion modules

Register [[Type Check Bound]] for declaration-time application validation.
Register [[Type Formation Builtins]] for the fixed type/carrier inventory.
Resolved Grill Log: ordinary generic definitions and derive members consume the
same canonical parameter-kind inventory without a new package dependency.

Register [[Type Implementation Rules]] and [[Type Trait Proof]] without new
dependencies. Resolved Grill Log: formed heads and bounded proof serve ordinary
checking and derive field publication through one semantic path.
Register [[Type Formation Shells]] for the unchanged pure nominal shell pass.
Register [[Trait Evidence Matching]] for isolated conditional-parameter inference.

Register [[Derive Record Residualizer]], [[Derive Residual State]],
[[Derive Reflection Facts]] and [[Compile Time Limits]] without new dependencies.
Resolved Grill Log: the pure phase kernel is independently testable while graph
publication and field proof remain explicit subsequent consumers.

Register [[Syntax Cache Provenance]] for the checked-product storage boundary.
Resolved Grill Log: validate authored identity before deferred encoding, without
changing the warm-reader format or adding dependencies.

Register [[Type Literal Frontier]], a pure bounded pending-constraint selector;
no dependencies or public Pudu syntax change. Resolved Grill Log: the checker
retains ownership and uses its existing monotone fresh-variable invariant.
