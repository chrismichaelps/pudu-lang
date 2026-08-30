---
type: decision
status: Accepted
date: 2026-08-29
tags: [decision, semantics, types, control-flow]
aliases: [ADR-0012, Diverging Blocks Preserve Never]
---

# ADR-0012 — Diverging blocks preserve `Never`

**Status: Accepted. Reviewed 2026-08-29.**

## Context

Pudu already assigns `Never` to `return`, `break`, and `continue` at a valid
control boundary, and `Never` joins with every type because its path produces no
value. The parser represents those transfers as statements, so a block ending
directly in one has no trailing result expression. The checker treated every
such block as unit.

Before this decision, a valid arm was rejected:

```pudu
match flag {
  case true => { return 1 }
  case false => 2
}
```

The first arm became `()`, and the second reported `E3001: expected (), found
Int`. `let … else` had to inspect its fallback's syntax as a private exception
to recognize the same divergence.

## Decision

A block yields its trailing result expression when present. Without one, a
block whose final statement is directly `return`, `break`, or `continue` has
type `Never`; every other resultless block has type `()`.

The rule is deliberately shallow. A nested conditional or match that may fall
through does not make its containing resultless block diverge merely because
one nested path transfers. Both inferred block typing and checking a block
against an expected type use this one classification. Consumers, including
`let … else`, ask the inferred type and do not repeat a structural exception.

## Compatibility and diagnostics

This is a backward-compatible semantic correction, advancing the draft semantic
version from `0.3.0-draft` to `0.4.0-draft`. Programs previously accepted keep
their meaning. Programs whose only rejected join was a direct-transfer block
beside a value are now accepted.

No diagnostic is added or removed for genuine fallthrough. A resultless block
ending in a binding remains unit; when joined with `Int`, the existing `E3001`
still points at the incompatible `Int` value. No migration is required.

## Runtime and backend conformance

The interpreter already propagates return and loop-transfer control without
constructing unit, so it changes nowhere. The native backend must preserve the
same rule when it is implemented: a `Never` path contributes no value to a
join. Type-check regressions cover direct `return`, `break`, and `continue`, an
ordinary fallthrough block, and the stable fallthrough diagnostic span.

## Consequences

- `if` and `match` joins follow the existing `Never` subtype rule consistently.
- `let … else` uses ordinary block typing and loses its special-case syntax
  check.
- Empty blocks, binding-ended blocks, and other reachable resultless blocks
  remain unit.

## Rejected alternatives

- **Keep consumer-specific exceptions.** This fixes `let … else` while leaving
  every other join wrong and creates multiple definitions of divergence.
- **Treat any block containing a transfer as `Never`.** A different path may
  reach the boundary, so containment alone is unsound.
- **Add a new diagnostic.** The defect rejects valid code; no new user mistake
  exists to diagnose.

## Referenced by

[[decisions/_MOC]] · [[architecture/SEMANTICS]] · [[grammar/pudu]] ·
[[Type Check Statement]] · [[handoffs/2026-08-29-diverging-block-never]] ·
[[ADR-0011-propagation-over-re-matching]]
