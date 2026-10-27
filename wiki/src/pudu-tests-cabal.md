---
type: module
path: "@root/pudu-tests.cabal"
fidelity: Active
tags: [module, build, test, packaging]
aliases: [Pudu Test Cabal Manifest]
---

# Pudu Test Cabal Manifest

Register Backend.UnsignedPrograms with existing dependencies. Resolved Grill
Log: unsigned source matrices execute through the ordinary conformance runner.

Register Backend.SignedPrograms with existing dependencies. Resolved Grill Log
(#497): all signed matrices enter the ordinary native, mathematical and frame
compilation corpora without a second test runner or new package.

Register Cli.MemorySpec and Backend.FrameRuntimeSpec with the existing IO/process
test dependencies. Resolved Grill Log (#499): controlled host exhaustion and
actual generated allocator lifecycle tests compile in the ordinary test suite.

Register Pudu.Backend.FrameEmitSpec explicitly. Resolved Grill Log (#499):
compile step bodies with the existing process/temp-directory test dependencies.

Register Pudu.Backend.FrameSpec explicitly using existing dependencies. Resolved
Grill Log (#499): pure frame transformation tests compile in the ordinary suite.

Register [[Eval Loop Step Tests]] explicitly. Resolved Grill Log: the internal
channel's typed refusal/transfer and cleanup semantics execute in the full suite
without adding dependencies or relying only on successful kernel values.

## Purpose and interface

Declare the repository-only `pudu-tests` package and its `pudu-test` exit-code suite. The package is
rooted beside `test/` and `test-fixtures/`, depends on the production `pudu` library through
[[Pudu Cabal Project]], and preserves every registered Haskell spec plus the C++ ownership fixture.

Separating this package makes the compiler's source distribution self-contained: installing the
`pudu` executable no longer asks Cabal to archive a source directory outside its package root.
`cabal test all` still discovers and runs the suite because both packages belong to one project.

## Invariants and negative logic

- The test package declares no library or executable shipped to users.
- Test sources remain single-copy under `test/`; the package layout changes, not test behavior.
- The suite depends on `pudu == 0.1.3` so it cannot silently validate a different compiler version.
- The native C++ fixture remains test-only and uses the same platform export flags.
- [[Pudu CLI Init Spec]] is registered explicitly and uses `temporary` for isolated filesystem
  evidence and `filepath` for portable project paths.
- [[Pudu Lint Spec]] and [[Pudu CLI Lint Spec]] are registered explicitly; CLI filesystem evidence
  uses the existing isolated `temporary` dependency.

## Grill Log

- **Q:** Copy `test/` beneath the compiler package? **A:** No. _Rationale:_ duplicated tests drift
  and add more than six megabytes to the release package. _Accepted:_ root the test package at the
  repository test tree.
- **Q:** Remove tests from `cabal test all` to make installation pass? **A:** No. _Rationale:_ that
  fixes packaging by deleting validation. _Accepted:_ two packages in one project.
- **Q:** Publish the test package as part of the compiler install? **A:** No. _Rationale:_ users need
  the compiler source archive, not repository fixtures. _Accepted:_ explicit installation and sdist
  gates target `pudu`, while repository CI targets `all`.
- **Q:** Exercise initialization in a developer's checkout directory? **A:** No. _Rationale:_ a
  refusal test deliberately creates collisions. _Accepted:_ per-property temporary directories
  deleted after the property completes.

## Method corpus (#551)

Resolved Grill Log: register [[Backend Method Programs]]; existing consumers
run it.

## Generic corpus (#552)

Resolved Grill Log: register [[Backend Generic Programs]].

## Try corpus (#553)

Resolved Grill Log: register [[Backend Try Programs]].

## For corpus (#554)

Resolved Grill Log: register [[Backend For Programs]].

## Closure corpus (#555)

Resolved Grill Log: register [[Backend Closure Programs]].

## Array corpus (#556)

Resolved Grill Log: register [[Backend Array Programs]].

## Array pattern corpus (#558)

Register Pudu.Backend.ArrayPatternPrograms ([[Backend Array Pattern Programs]]).

## Text collection corpus (#559)

Register Pudu.Backend.TextCollectionPrograms ([[Backend Text Collection Programs]]).

## Convert corpus (#560)

Register Pudu.Backend.ConvertPrograms ([[Backend Convert Programs]]).

## Keyed corpus (#561)

Register Pudu.Backend.KeyedPrograms ([[Backend Keyed Programs]]).

## Shape corpus (#563)

Register Pudu.Backend.ShapePrograms ([[Backend Shape Programs]]).

## Range corpus (#564)

Register Pudu.Backend.RangePrograms ([[Backend Range Programs]]).

## Bytes corpus (#565)

Register Pudu.Backend.BytesPrograms ([[Backend Bytes Programs]]).

## Referenced by

[[Derive Graph Spec]] is explicitly registered for real program elaboration,
lexical capture, conditional rules and diagnostic/output checks in both modes.

[[Pudu Cabal Manifest]] · [[Pudu Cabal Project]] · [[Release Readiness and Native UI Canvas]]

Reflection Resolution Spec is registered beside ordinary resolution properties,
covering selected and first-class metadata imports, namespace shadowing and
repeated rigid loop bounds. Resolved Grill Log: explicit registration makes
these boundary tests execute in the full suite.

[[Program Reflection Spec]] is registered explicitly and aggregated by [[Program
Spec]]. Resolved Grill Log: temporary complete programs check the actual shipped
Meta facade and imported method schemes, including refusal diagnostics.

[[Generated Identity Spec]] is registered explicitly. Resolved Grill Log: source,
checker and persistence identity regressions execute in the full suite.

[[Derive Record Kernel Spec]] is registered explicitly and exercises generated ordinary
implementations in both evaluator modes. Resolved Grill Log: actual expansion output
is checked, with graph publication retained as a distinct integration gate.

Register [[Type Implementation Proof Spec]]. Resolved Grill Log: ordinary caller,
dynamic, imported and bounded solver regressions execute through the shared proof.

Register [[Type Literal Frontier Spec]] for generated ordered-selection laws,
unvisited-suffix proof and actual width/diagnostic compatibility. No new testing
dependency. Resolved Grill Log: deterministic work evidence accompanies the
benchmark; no host-specific timing gate.

Register [[Runtime Series Map Tests]]. Resolved Grill Log: storage snapshot,
representative and signed-boundary laws execute through the actual coordinator
without a new test dependency.

Register [[Derive Catalogue Spec]] explicitly with no new dependency. Resolved
Grill Log: canonical inventory and refusal evidence run in the complete suite.

Register [[Derive Requirement Spec]] explicitly. Resolved Grill Log: shared
solver inference, rollback and bounded refusals execute in the complete suite.

Register [[Derive Target Spec]]. Resolved Grill Log: canonical payload preparation
and structural type reconstruction run without implying executable graph delivery.

Register [[Derive Cache Spec]]. Resolved Grill Log: actual warm frozen consumers,
compile-time content keys and transitive/cyclic import closure execute in the suite.

Register [[Derive Library Spec]]. Resolved Grill Log: every shipped derive,
field callbacks, static selection and the expansion snapshot run in both
evaluators within the complete suite.

Register [[Lsp Impl Members Spec]]. Resolved Grill Log: implementation member completion and its quick fix run through the server's request path in the complete suite.

Register [[Module Qualifier Spec]] explicitly. Resolved Grill Log: isolated/loaded identity, privacy, recovery, diagnostic and execution evidence runs in the complete suite without a new dependency.

## Qualified shadow registration (#471)

Register Qualified Shadow Spec with the existing test dependencies. Resolved Grill Log: complete loaded and isolated lexical evidence must compile and execute in the repository suite.

Register [[Mutex Admission Spec]] explicitly with existing dependencies. Resolved Grill Log (#476): the controlled native family and real public fixture run in the complete suite.

Register [[Database Challenge Spec]] explicitly with existing dependencies. Resolved Grill Log: complete-suite execution and focused execution use the same real challenge admission assertions.

## Native function and process regressions (#488)

Register [[Backend Function Programs]] as the native function corpus and [[Backend Toolchain Tests]] as an executed property family. Resolved Grill Log: the full suite must run independent differential and adversarial process regressions through static registration; no new test dependency.

## Native control flow (#489)

Register the loop-control lowering helper and native control-flow property/corpus modules through explicit module lists and the existing test aggregator. Resolved Grill Log: no new dependency or source discovery; focused and full suites execute the same control-flow evidence.

## Unit conditional conformance (#490)

Register [[Eval If Unit Tests]] explicitly and execute its property family alongside
ordinary evaluator checks. Resolved Grill Log: include unit-result, contextual
Dynamic, constant and actual boxed-kernel regressions in focused and full runs.

## Native solved facts (#491)

Register and run [[Native Solved Types Tests]] alongside backend properties. Resolved Grill Log: missing/colliding facts and canonical identity checks execute in the full suite.

## Platform Int operators (#495)

Register Pudu.Backend.IntegerPrograms explicitly in other-modules beside existing native corpora, with no new dependency.

Resolved Grill Log: boundary and failure matrices execute real native binaries; fixed repeated properties are not described as randomized sampling. Keep full numeric-family coverage pending.

## Exact integer carrier integration (#498)

Register Pudu.Backend.DeferredPrograms explicitly. Existing native property
groups execute its success and refusal lists through the same real compiler,
interpreter/native and mathematical expected-output harness.

Resolved Grill Log: implement [[Exact Native Integer Carriers]] without changing the oracle. Preserve positive boundary values, exact diagnostic provenance, Never transfers, and warning-free helper selection. The internal carrier is not a public type-layout promise; full native coverage remains open.

## Portable wide-word prerequisite

Register [[Native Word128 Tests]] with existing test dependencies.
Resolved Grill Log: actual strict C11 execution must validate the prerequisite without claiming typed emission admission.

## Exact wide values (#502)

Register [[Native Wide Value Tests]] using existing test dependencies.
Resolved Grill Log: helper-selection and exact-sign checks must execute without admitting source types early.

## Typed wide operation registration (#503)

Register [[Native Wide Operation Tests]] with existing test dependencies, plus a generated C setjmp failure fixture.
Resolved Grill Log: execute independent mathematical/refusal and minimal-closure evidence; source admission remains a later obligation.

## Wide runtime integration (#504)

Register [[Native Wide Runtime Tests]] with existing test dependencies.
Resolved Grill Log: actual production runtime selection/output/failure evidence must execute before wide-frame/source admission.

## Closed-output regression (#505)

Register [[Native Broken Pipe Tests]] with existing test dependencies and a conditional POSIX launcher.
Resolved Grill Log: restore default SIGPIPE in a separate launcher so inherited evaluator policy cannot mask the native defect.

## Wide frame execution (#506)

Register and execute [[Native Wide Frame Tests]] with existing dependencies.
Resolved Grill Log: the actual Core/frame C11 corpus and cleanup checks run in
focused and complete suites; public source admission remains pending.

## Floating natural prerequisite (#508)

Register [[Native Floating Natural Kernel]] and [[Native Floating Natural Tests]]
as appropriate to production/test components, using existing dependencies.
Resolved Grill Log: execute exact C11 helper evidence without admitting Float
source, changing the active runtime ABI or adding a native dependency.

## Exact binary64 formatting (#509)

Register [[Native Binary64 Formatter]] and [[Native Binary64 Formatter Tests]]
in the appropriate production/test components with existing dependencies.
Production license-files includes [[Native Floating Notices]] alongside LICENSE.
Resolved Grill Log: preserve the project license and upstream attribution,
without source admission, runtime file lookup or a new native dependency.

## Floating values (#510)

Register [[Native Floating Values]] and [[Native Floating Value Tests]] in their
production/test components using existing dependencies. Resolved Grill Log:
raw-bit arithmetic evidence precedes source admission; runtime selection and
ABI revision remain unchanged in this prerequisite.

## Floating runtime selection (#511)

Register [[Native Floating Runtime]], [[Native Runtime Dependencies]] and
[[Native Floating Runtime Tests]] in the appropriate components with existing
dependencies. Resolved Grill Log: execute actual catalogue/output evidence
without changing source admission or the represented runtime ABI.

## Float programs (#512)

Register Pudu.Backend.FloatPrograms in other-modules beside the integer corpora; no new dependency.

## Text programs (#515)

Register Pudu.Backend.TextPrograms and Pudu.Backend.TextLeakSpec in other-modules; no new dependency.

## Text method programs (#516)

Register Pudu.Backend.TextMethodPrograms in other-modules.

## Text case tests (#517)

Register Pudu.Backend.TextCaseSpec in other-modules.

## Char programs (#518)

Register Pudu.Backend.CharPrograms in other-modules.

## Tuple programs (#521)

Register Pudu.Backend.TuplePrograms in other-modules.

Register Pudu.Eval.RecordOrderSpec in other-modules (#519).

Register Pudu.Eval.FloatOrderSpec in other-modules (#522).

Register Pudu.Backend.RecordPrograms in other-modules (#521).

## Shared reference corpus (#544)

Resolved Grill Log: register [[Backend Shared Reference Programs]] explicitly.
Existing ModulePrograms and TextLeakSpec consumers execute its programs, and
LowerTypesSpec's runner-consumed list executes reference fact/refusal checks.
No new dependency or Main coordinator is required.

## Output Results (#566)

Resolved Grill Log: Register Pudu.Backend.OutputPrograms and Pudu.Backend.OutputSpec using existing dependencies.

## Expression bodies (#567)

Resolved Grill Log: Register Pudu.Backend.ExpressionBodyPrograms with existing dependencies.

## Named callable dispatch (#568)

Resolved Grill Log: Register Pudu.Backend.NamedCallablePrograms using existing dependencies.

## First-class output builtins (#569)

Resolved Grill Log: Register Pudu.Backend.OutputCallablePrograms using existing dependencies.

Register [[Backend Rendering Callable Programs]] explicitly. Resolved Grill
Log: shared intrinsic corpus registration makes all new cases compile and run
without a new test dependency or release-gate change.

## Collection callable corpus (#631)

Register [[Backend Collection Callable Programs]]. Resolved Grill Log: no new
dependency; the release gate is unchanged.

## Stopping builtin corpus (#633)

Register [[Backend Stopping Builtin Programs]]. Resolved Grill Log: no new
dependency; the release gate is unchanged.

## Default parameter corpus (#638)

Register [[Backend Default Parameter Programs]]. Resolved Grill Log: no new
dependency; the release gate is unchanged.

## Method value corpus (#644)

Register [[Backend Method Value Programs]]. Resolved Grill Log: no new dependency.
