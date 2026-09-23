---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Version.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, versions]
aliases: [Package Version]
---

# Package Version

## Purpose and interface

Semantic versions and the requirements that select them. `parseVersion` reads `MAJOR.MINOR.PATCH` with an optional pre-release and refuses build metadata and leading zeros; `Ord` follows version precedence (a pre-release before its release, numeric fields numerically, a number before a word). `parseRequirement` reads `1.4`, `^1.4.2`, `~1.4`, `=1.4.2`, `>=1.2, <1.8`, and `*`; a bare version means caret, missing parts count as zero, and `0.x` carets stay within the minor. `satisfies` accepts a pre-release only when the requirement names a pre-release of the same three numbers.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Accept build metadata? **A:** No. _Rationale:_ two archives would share one version. _Rejected:_ ignoring metadata.
- **Q:** Let `^1.4` pick `1.5.0-beta`? **A:** No. _Rationale:_ asking for a compatible release is not asking for an unfinished one. _Rejected:_ plain ordering.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
