---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Solve.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, resolution]
aliases: [Package Solve]
---

# Package Solve

## Purpose and interface

Chooses one version per package. Registry wants carry requirements; every requirement on a package is collected, candidates are the releases satisfying all of them (a yanked release only if locked), ordered with the locked version first and then newest first, and a candidate whose own requirements cannot be met is abandoned for the next. Fixed wants (repositories and directories) arrive already expanded; two sources for one package are a conflict. A failure lists each requirement and who asked. `Registry` is the interface to releases and archives; `noRegistry` refuses registry packages.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Choose a release published within the minimum release age? **A:** Only when the lock holds it or a requirement names it exactly (`=1.2.3`). _Rationale:_ a poisoned release is usually pulled within hours. _Rejected:_ ignoring age, and refusing exact requests.

- **Q:** Allow two versions of one package? **A:** No. _Rationale:_ module and type identity carry no package qualifier. _Rejected:_ nested copies.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
