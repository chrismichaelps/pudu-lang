---
type: handoff
status: IMPLEMENTATION
issue: 190
tags: [handoff, repl, tooling, higher-kinded-types]
---

# Higher-Kinded REPL Inspection

## Defect

The parser and checker preserve `TypeParam.typeParamArity`, but [[Repl Describe]]
does not. `:info` renders `F[_]` as `F`, and `:kind` counts parameters as though
each accepted an ordinary type. Inspection therefore changes the signature it
claims to describe.

## FMCF Role Transition and Ownership

The **Language Architect** fixes the public notation here: this is constructor
shape already declared by Pudu source, not a new kind system. The
**Tooling/Release Engineer** then owns `src/Pudu/Repl/Describe.hs`, focused REPL
inspection tests, [[Repl Describe]], [[Pudu REPL]], their MOC/backlinks, this
handoff, and the changelog. The implementation changes no parser, checker,
evaluator, LSP feature, installed-binary workflow, or Pudu semantics. Other work
may exist in the repository; preserve it and do not revert unrelated changes.

## Contract

- `:info` renders arity zero as `T`, one as `F[_]`, two as `P[_, _]`, and
  retains bounds after that marker.
- `:kind` maps an ordinary parameter to `type`, a unary constructor parameter
  to `(type -> type)`, and a binary constructor parameter to
  `(type -> type -> type)`, then appends the declaration result `type`.
- Parentheses distinguish one higher-order input from several ordinary inputs.
- Wired-in constructor answers and unknown-name text remain byte-for-byte
  unchanged.
- Loaded and interactive declarations consume the same module projection and
  must answer identically.

## Review

An independent implementation reviewer must verify lossless rendering for
functions, types, and traits; mixed arity order; the associativity expressed by
parentheses; first-order regressions; and the absence of checker or evaluator
work in descriptions. An independent Forensic Guardian must verify mirror
fidelity, resolved Grill decisions, MOC/backlinks, changelog, exact handoff,
private-boundary compliance, and the review-size gate.

## Grill Log

- **Q:** Is this a kind-system feature? **A:** No. _Rationale:_ the syntax tree
  already stores the arity explicitly and the checker already enforces it;
  inspection is repairing a lossy projection. _Rejected:_ kind inference, kind
  variables, or a new semantic phase.
- **Q:** Can `Higher[F[_]]` print `type -> type -> type`? **A:** No.
  _Rationale:_ that denotes two ordinary inputs under the REPL's notation,
  while `Higher` accepts one unary constructor. Parentheses preserve the input
  boundary. _Rejected:_ flat arrow chains; parameter counts.
- **Q:** Should use sites determine the displayed arity? **A:** No.
  _Rationale:_ an unused parameter still has the shape declared at its binder.
  _Rejected:_ scanning applications or inferred checker state.

## Exact Next Action

Implement the vault contract in `Pudu.Repl.Describe`, add focused loaded and
interactive regressions, and run the REPL session gate before the first
behavior commit.

## Referenced by

[[handoffs/_MOC]] · [[Repl Describe]] · [[Pudu REPL]]
