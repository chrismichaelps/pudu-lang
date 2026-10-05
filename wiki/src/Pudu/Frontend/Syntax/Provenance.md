---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Frontend/Syntax/Provenance.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
tags: [module, cache, derive]
aliases: [Syntax Cache Provenance]
---

# Syntax Cache Provenance

## Purpose and interface

`cacheableSpan :: Source -> Span -> Bool` checks one fact key.
`cacheableModule :: Source -> Module -> Bool` verifies every syntax span belongs
to the supplied authored snapshot and carries no generated origin. The compiler
cache uses this before storing a tree with deferred declarations or bodies.

## Algorithm

A private generic structural fold visits all AST fields; primitive values and
paths hold no spans, Located checks its own span and value, Span compares actual
snapshot identity and origin. Lists, Maybe and NonEmpty traverse their members.
Explicit instance registration covers every syntax product, so adding a new field
to a registered AST constructor extends the walk without a permissive expression
catch-all. The walk short-circuits on the first unsupported origin.

## Edge cases and negative logic

A generated span inside an otherwise authored function body refuses the entire
entry before lazy encoding. Foreign same-name snapshots also refuse. Ordinary
products retain existing serialization and deferred-read behavior. No textual
byte scanning, source-name identity, decoder exception or whole-tree generic Eq.

## Grill Log

- **Q:** Rely only on a Span decoder miss? **A:** No; deferred declarations may
  expose the invalid span only after a successful cache lookup. _Rationale:_ an
  unsupported generated product must never become a latent body-decoding fault.
  _Rejected:_ scanning encoded bytes for a marker or forcing all warm reads.

## Referenced by

[[Compiler Cache]] · [[Syntax Tree]] · [[src/Pudu/Frontend/Syntax/_MOC]]
