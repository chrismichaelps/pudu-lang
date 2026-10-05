---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Definition.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, types]
aliases: [Validated Derive Definitions]
---

# Validated Derive Definitions

## Purpose and interface

`validateDefinitions` admits each defining module once against the preliminary
body-free interface graph and produces an abstract `ValidatedDefinitions` plus
per-module diagnostics. `validatedCandidate` selects a candidate only when its
defining module was admitted. Each abstract `ValidatedDefinition` exposes its
candidate, resolved reflection facts and defining resolution for capture planning.
Only this module constructs validated products.

## Algorithm and invariants

Private functions/constants with unwritten contracts referenced by templates are
inferred once before generic bodies, using [[Derive Capture Inference]]'s resolved
transitive closure. Reuse ordinary full resolution for that closure and retain
only needed helper body findings, plus the projection's signature/template
findings. Annotated helpers expose their declared contracts; unrelated ordinary
bodies remain deferred. No new private-helper annotation requirement is added.
Resolved Grill Log: an inferred helper cannot be assigned different contracts by
different generated requests or report its mistake once per target.

Build a definition view retaining all declaration names, type shapes, annotations
and imports, with ordinary function/trait/impl bodies removed and constant
initializers replaced by unit. Keep derive bodies untouched. Resolve this view
under the existing export index, then run [[Type Check]]'s definition-only boundary
when resolution admits it. Ordinary bodies do not run, fold or type-check during
this pass. Typing receives the original declaration syntax so local trait default
availability is preserved; its definition-only boundary ignores ordinary bodies.
Request and inline derive names participate in the signature resolution
projection, retaining ordinary unknown-name diagnostics before catalogue policy.
Save one resolved
product for each admitted defining module and reuse
it for every candidate/request; invalid modules supply diagnostics without a
validated product. Modules without definitions resolve headers only and perform
no generic body checking.

## Negative logic and edge cases

No per-request generic checking, unchecked construction, runtime metadata,
filesystem access or source-string generation. Signature/context errors prevent
definition admission; later ordinary body errors still prevent executable graph
admission. Inaccessible and missing candidates remain catalogue/request policy.
Imported bodies never run. Trait defaults remain known through the original
declarations and preliminary graph even though definition-view bodies are removed.

## Grill Log

- **Q:** Resolve ordinary callers before generated heads exist? **A:** Resolve
  only definition bodies plus shared declaration syntax. _Rejected:_ evaluating
  callers, checking templates per concrete target or ignoring definition errors.
- **Q:** Export the validated constructor? **A:** Keep it abstract. _Rationale:_
  the graph cannot silently promote an unvalidated catalogue entry. _Rejected:_
  boolean flags whose caller can assert validity.
- **Q:** Replace the original module with the definition view? **A:** No; it is
  an internal checking projection only. _Rejected:_ losing ordinary bodies,
  authored syntax or lexical definition captures from the executable graph.

## Linkage and references

Requires [[Derive Catalogue]], [[Derive Reflection Facts]], [[Name Resolution]],
[[Type Check]] and [[Type Interface Graph]]. Referenced by [[Derive Design]] ·
[[src/_MOC]].
