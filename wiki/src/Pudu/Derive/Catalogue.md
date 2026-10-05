---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Catalogue.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, graph]
aliases: [Derive Catalogue]
---

# Derive Catalogue

## Purpose and interface

`collectCatalogue` forms an abstract graph-local inventory of candidate derive
definitions and requests. Definitions retain their defining module and syntax;
requests retain the consumer, authored anchor, canonical full trait application,
target declaration/application and bound parameters. This inventory is not a
validated product and cannot by itself authorize head publication.
`collectCatalogueWith` reuses the graph phase's prepared preliminary interfaces.

## Algorithm and invariants

Prepare body-free interfaces once. Form each module's local declaration scope
over its import overlay, using ordinary alias expansion and canonical nominal
identities. Index aggregate declarations by canonical owner. Index definitions
by canonical trait owner and Record/Sum shape; reject duplicate pairs across
modules, including aliases, and remove ambiguous candidates entirely. Collect inline requests in declaration order and
external requests under their written anchor. Resolve aliases to the actual
target aggregate and select its shape. Preserve full target/trait arguments.
Inline generic requests bind their declaration's own parameter names and kinds.
Reject duplicate canonical trait requests for one inline type, unknown traits,
nonaggregate targets and absent/inaccessible strategies with located E3091.
Ordinary generated impl checking remains responsible for orphan/coherence rules.

## Negative logic and edge cases

No body checking, evaluation, generated implementation, filesystem access or
trait-name special cases. Public candidates may be consumed throughout the loaded
graph; a private strategy is visible only in its defining module. Invalid source
modules do not enter the inventory. Aliases do not create a second trait or target.
Record and Sum strategies for one trait remain distinct. All declaration order
and diagnostic order are deterministic; catalogue state never survives a graph.

## Grill Log

- **Q:** Key requests by written trait spelling? **A:** Use canonical nominal
  identity and retain the full application. _Rejected:_ alias-dependent strategy
  selection or treating Eq and Json as compiler-known identities.
- **Q:** Treat a candidate as generically validated? **A:** No; the separate graph
  phase must admit the defining module once before residualization. _Rejected:_
  checking only used definitions or publishing provisional unchecked methods.
- **Q:** Copy imported declarations into the consumer? **A:** No; project scopes
  from the existing interface graph. _Rejected:_ synthetic ownership and privacy
  changes through AST concatenation or added imports.

## Linkage and references

Requires [[Type Interface Graph]], [[Type Formation]], [[Syntax Tree]] and
[[Diagnostic Model]]. Referenced by [[Derive Design]] · [[src/Pudu/_MOC]].
