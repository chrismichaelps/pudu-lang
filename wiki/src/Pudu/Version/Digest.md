---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Version/Digest.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, tooling, bundle, deployment]
aliases: [Version Digest]
---

# Version Digest

## Purpose

A compile-time splice naming what the compiler was built from, so checked products can travel to
any runtime built from the same text — including one for another platform.

## Interface

- `sourceDigestLiteral :: Q Exp` — the literal `PUDU-SOURCE-DIGEST:<64 hex>;`.

## Algorithm

Every `.hs` under `src`, every `.c`, `.h`, `.m` under `cbits` (sorted), then `pudu.cabal`, each
framed as `relative path \0 length \0 bytes`, hashed with SHA-256. Each file is registered with
`addDependentFile`, so editing any of them recompiles the splice; a new module changes
`pudu.cabal`, which is itself hashed.

## Grill Log

- **Q:** Hash the product schema instead of the sources? **A:** No. _Rationale:_ products encode
  checked meaning as well as format, and a change to the checker leaves the schema intact while
  making old products wrong. _Rejected:_ a Generic shape fingerprint.
- **Q:** Include `app/`? **A:** No. _Rationale:_ the executable's command handling does not decide
  what a product means, and the splice lives in the library.
- **Q:** Line endings? **A:** Bytes are hashed as checked out; releases build from Unix checkouts,
  and a checkout that rewrote line endings is a different source.

## Referenced by

[[Pudu Version]] · [[Pudu Bundle]] · [[src/Pudu/_MOC]]
