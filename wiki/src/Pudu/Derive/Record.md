---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Record.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, expansion]
aliases: [Derive Record Residualizer]
---

# Derive Record Residualizer

## Purpose and interface

`instantiateRecord` accepts a generically checked derive, target record declaration,
request trait/target syntax and request span, and canonical [[Derive Reflection Facts]].
It publishes an ordinary Impl plus structured field obligations, or a located
ExpansionFailure. No individual trait name is known. Graph orchestration must
validate definitions once and prove the obligations before publishing this product.
This module is the record phase kernel, not a complete graph-delivery claim.

## Algorithm

Create request-owned bounded state. Substitute the shape parameter with the target
syntax; each fields iteration binds a descriptor and its independently selected F.
Read name/attributes as literals, preserve strict runtime fallback evaluation
even when an attribute is present, get as an ordinary field projection, set as an
assignment, and nameOf as a declared-name literal. Static booleans select only the
reachable branch; runtime conditions retain ordinary branches. Unroll fields into
separate ordinary blocks preserving binding scope, order and transfers. All newly
created Located nodes receive distinct generated spans with authored provenance.
Collect each loop's field bounds for the semantic proof layer.

## Edge cases and negative logic

Lexical parameters, patterns and declarations shadow descriptors before entering
their bodies. Runtime values never become metadata and unresolved metadata escapes
are refused. Recurse through lambdas, explicit applications and every ordinary
control construct. A request has bounded node work, depth and iteration count;
rejection returns no partial impl. Sum expansion and polymorphic builders belong
to separate kernels; encountering those returns a typed failure in this kernel.
Never generate source strings, fabricate offsets, add imports, bypass privacy,
choose methods by runtime result values or infer a missing field capability.

## Grill Log

- **Q:** Re-check the derive for each record? **A:** No; consume its validated
  definition product and publish field obligations separately. _Rationale:_ author
  errors belong once at the definition; use sites prove capabilities. _Rejected:_
  compiler-known Eq/Json cases or accepting unproved conditional impls.
- **Q:** Flatten unrolled local bindings into the surrounding block? **A:** No;
  retain each original body scope. _Rationale:_ declarations in different field
  iterations cannot capture each other. _Rejected:_ text substitution and fresh
  names without lexical scope.
- **Q:** Let unsupported reflection survive? **A:** No; return a typed failure.
  _Rationale:_ Meta declarations are compile-time only. _Rejected:_ runtime panic
  bodies serving as an expansion fallback.

## Referenced by

[[src/Pudu/_MOC]] · [[Derive Design]] · [[Derive Residual State]]
