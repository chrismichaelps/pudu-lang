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

Field callbacks (`build`, `collect`, and their variant forms) unroll through [[Derive Field Callbacks]], which receives this module's walkers; shared state lives in [[Derive Residual Context]]. A static call through a substituted type parameter, `F.decode(json)`, becomes a member of the field type's canonical owner. `variant.positional` folds to whether the payload is positional or unit. Every generated block passes through [[Statement Inlining]].

## Algorithm

Sum variant loops bind a SelectedVariant, fold its name/index and attributes,
and lower matches to ordinary if-let. Nested variant.fields loops share the
same field substitution and obligation pipeline as records. Sum payload reads
delegate to [[Derive Sum Residualizer]] and preserve its ordinary mismatch
outcome. Metadata descriptors shadow independently from pure unrolled values.

`instantiateAggregateIn` also accepts an admitted Sum template with ordinary
shape-independent expressions and nameOf. Record-specific field reflection
requires a Record shape; unsupported Sum reflection remains an explicit failure
until its descriptor kernel is added. This is not a complete Sum delivery claim.
Known literal-array compile-time loops unroll into separate lexical blocks;
their values substitute simultaneously through a shadow-aware value environment.
[[Derive Syntax]] owns shared pattern traversal and structural shape comparison.

`instantiateRecordIn` is the same kernel inside an existing request-owned Residual
state. The original `instantiateRecord` wrapper remains available for focused
kernel tests. [[Derive Graph]] owns target preparation, canonical head syntax,
and the final declaration in that same state, preventing ordinal collisions.
Type substitutions are simultaneous: an actual replacement is never rewritten
through another template binder. Prepared target parameter bounds are retagged
without shape substitution. Resolved Grill Log: a request parameter named T or F
cannot be captured by the shape parameter or per-field binder of the template.

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
- **Q:** Emit a static call as a dotted name? **A:** No; as a member on the owner path, the shape authored `A.parse(x)` has, which checking and both evaluators already resolve.
- **Q:** Keep callback unrolling here? **A:** No; it moved beside its construction helpers to keep both modules under 500 lines.

## Referenced by

[[src/Pudu/_MOC]] · [[Derive Design]] · [[Derive Residual State]]

## Static field owner selection (#457)

Retain a substituted generic owner's complete type as the target of its static member:
`F.read` becomes `Option[Int].read`, using ordinary member and type-application syntax.
Resolved Grill Log: erasing owner arguments leaves a discarded collect result unconstrained;
blindly treating owner arguments as implementation parameters breaks reordered or nested heads.
The checker selects through the complete owner; derive expansion never selects an implementation.
