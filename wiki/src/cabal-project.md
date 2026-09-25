---
type: module
path: "@root/cabal.project"
fidelity: Active
tags: [module, build, project, packaging]
aliases: [Pudu Cabal Project]
---

# Pudu Cabal Project

## Purpose and interface

Bind the production [[Pudu Cabal Manifest]] and repository-only [[Pudu Test Cabal Manifest]] into one
build plan with the locked Hackage index state, tests enabled, and development optimization disabled.
The project lets `cabal build all` and `cabal test all` validate both packages while a targeted
`cabal sdist pudu` or `cabal install exe:pudu` contains only the self-contained compiler package.
The production package stays first because release scripts intentionally parse that first selection
as the active version series; the root test package is a continuation, not the release target.

## Negative logic

- The project does not add a second compiler package or duplicate source directories.
- Repository test configuration must not leak an outside-path component into the production package.
- The pinned index state changes only through an intentional dependency update.

## Grill Log

- **Q:** Keep one package solely to minimize project metadata? **A:** No. _Rationale:_ that made the
  release archive unsafe. _Accepted:_ package boundaries follow the physical source boundaries.
- **Q:** Disable tests during normal development? **A:** No. _Rationale:_ `all` remains the standard
  regression target. _Accepted:_ the test package is independently targetable.

## Referenced by

[[Pudu Cabal Manifest]] · [[Pudu Test Cabal Manifest]] · [[src/_MOC]]
