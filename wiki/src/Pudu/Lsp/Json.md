---
type: module
path: "@root/src/Pudu/Lsp/Json.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Json]
---

# Lsp Json

## Purpose

Read and write the JSON the protocol carries.

## Interface

The exported signatures are the module header's export list.

### Governance

- Hand-written for the reason [[Doc Json]] already gives: the protocol's shape is fixed and small, and a dependency would put this project's contract with every editor on somebody else's release schedule. The existing encoder only *wrote* JSON; a server has to read it too, which is the half this module adds.
- Trailing content after a complete value is a failure rather than ignored: a body carrying more than it declared is a framing bug, and accepting it would hide one.
- A trailing comma is refused. A parser that accepts input the format does not is a parser that disagrees with the client about what was sent.
- A surrogate pair joins into one scalar, because a client sending an astral scalar sends it as a pair and treating the halves separately would produce text that is not what was sent. An unpaired surrogate is refused.
- A fractional position is malformed rather than rounded: rounding one would silently point at a different character.
- A whole number encodes without a fractional part, because `3.0` is legal JSON that some clients read as a float and then reject.

### Linkage

- **Requires:** [[Source Text]], [[Diagnostic Model]].
- **Consumed by:** [[Language Server]].

## Algorithm

Direct structural recursion over the shape being read or written; no caching and no mutation.

## Negative Logic (Prohibited Paths)

- No compilation, no analysis, and no decision about what a program means.
- No acceptance of input the format does not admit.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Language Server]] · [[Tooling]]
