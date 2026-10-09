---
type: module
path: "@root/pudu-tests.cabal"
fidelity: Active
tags: [module, build, test, packaging]
aliases: [Pudu Test Cabal Manifest]
---

# Pudu Test Cabal Manifest

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
