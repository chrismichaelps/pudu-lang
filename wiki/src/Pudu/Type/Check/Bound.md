---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Check/Bound.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, trait, derive]
aliases: [Type Check Bound]
---

# Type Check Bound

## Purpose and interface

Validate written generic bounds before their bodies can assume them.
`checkDeclarationBounds` validates a declaration and its members; `checkBounds`
validates parameter/where requirements under complete enclosing rigid kinds.
Both return admission as well as located E3048 diagnostics. They neither prove
capabilities nor inspect any implementation body.

## Algorithm

Project each bound through ordinary canonical `formBoundFor`, including the
established same-kind constructor shorthand. Require a declared canonical trait
or an ownerless compiler marker. Match the trait's complete parameter inventory,
then recursively check each argument's arity. Bare named constructors and rigid
constructor parameters have their declared arity; a fully applied type has arity
zero. Partial applications, trait arguments used as value types and incompatible
constructor arguments refuse at the written bound. Bounds on a non-parameter
subject refuse rather than lending assumptions to a nominal declaration.

The declaration walk covers type, trait, implementation and function parameters,
where clauses and ordinary/derive members. Implementation heads validate their
explicit trait applications separately from subject-bound shorthand. Checking
does not repeat bodies or rewrite their source.

## Edge cases

Self is an enclosing rigid parameter in a trait or implementation member.
Missing names remain resolution failures; error poison suppresses follow-on
kind errors. Built-in container arities are the fixed language inventory, while
user and imported constructor kinds come from canonical declaration facts.
Opaque imports in isolated editor buffers provide no authoritative declaration
inventory; defer those unknown heads to a loaded program instead of fabricating
a kind or refusing a name whose interface was not supplied.
Formation diagnostics and the existing derive-contract diagnostic remain owned
by their original phases. Repeated declaration checking reports one E3048 per
complete source span. Compile-time loops validate under their newly bound field
parameters, before their bodies can use those assumptions.

## Negative logic

Do not infer constructor arity from use, accept partial constructor applications,
erase trait arguments, mutate inference or prove an instance from its owner.
No filesystem access, evaluation, generated impl publication or derive-name
special cases. Validation is linear in the written bound's formed structure;
signature installation remains a pure projection rather than a second body pass.

## Grill Log

- **Q:** Reject only when a caller requests the invalid bound? **A:** Reject at
  its declaration, including unused derives. _Rationale:_ a generic definition
  cannot assume malformed evidence. _Rejected:_ delayed E3012 at each caller.
- **Q:** Treat a bare constructor as an ordinary value type? **A:** Its arity
  must match the receiving trait parameter. _Rationale:_ ADR-0014 admits named
  constructors, not partial application or a kind language. _Rejected:_ guessing
  constructor arguments or accepting any nominal name.
- **Q:** Share generic member validation with derives? **A:** Yes. _Rationale:_
  the same declared trait applications supply their assumptions. _Rejected:_
  compiler-known derive exceptions.

## Referenced by

[[Type Check]] · [[Type Check Expression]] · [[Type Formation]] ·
[[Type Implementation Proof Spec]] · [[src/Pudu/Type/_MOC]]
