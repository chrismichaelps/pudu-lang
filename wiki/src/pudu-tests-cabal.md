---
type: module
path: "@root/pudu-tests.cabal"
fidelity: Active
tags: [module, build, test, packaging]
aliases: [Pudu Test Cabal Manifest]
---

# Pudu Test Cabal Manifest

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
- The suite depends on `pudu == 0.1.0` so it cannot silently validate a different compiler version.
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

[[Pudu Cabal Manifest]] · [[Pudu Cabal Project]] · [[Release Readiness and Native UI Canvas]]
