---
type: architecture
aliases: [Native Expression Bodies]
tags: [backend, lowering, callables]
---
# Native Expression Bodies

A checked named function with an expression body evaluates that expression
and returns its value, just as the evaluator's closureOutcome does. Admit
expression bodies at the existing entry and reachable-function boundaries.
No source or checker semantics change.

## Resolved Grill Log

- Normalize a located expression body to a synthetic empty lexical block
  whose trailing expression is the original located expression. Keep the
  body span and every expression span; do not rebuild checked expressions
  or synthesize type facts.
- Reuse lowerBlock for evaluation, explicit return/try unwinding, Never,
  owned results and refusal containment. The extra empty lexical scope has
  no observable binding, effect or call-depth cost.
- Keep source modifiers, default-parameter and unsupported type restrictions.
  Removing the body-shape refusal must not broaden another boundary.
- Entry result selection and non-entry settled signatures stay unchanged.
  Methods and generic copies pass through the same reachable body lowering.
- Prove explicit outputs, expression-entry rendering, owned/captured values,
  argument order, recursion/depth boundaries, failure provenance and cleanup
  with the actual tree and compiled evaluators. Do not alter their behavior.

## Ownership and delivery

Backend Engineer owns Compiler/Lower/{Signature,Body}.hs and the bounded
ExpressionBodyPrograms corpus with native/cleanup registration and obsolete
refusal updates. Test Engineer runs the focused lane. Forensic Guardian
self-audits wiki parity; independent review remains pending. No sub-agents.
Full gates and release workflows remain unchanged; full validation is a
promotion obligation rather than an iteration step.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native Expression Body Delivery]] · [[Compiler Lower Body]] · [[Compiler Lower Signature]]
