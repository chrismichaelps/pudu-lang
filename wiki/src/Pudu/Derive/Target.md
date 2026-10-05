---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Target.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, types]
aliases: [Derive Target Application]
---

# Derive Target Application

## Purpose and interface

`prepareTarget` accepts the declaring scope and a canonical request, producing
the aggregate shape with declaration parameters replaced simultaneously by the
request's actual arguments. `reifyType` reconstructs canonical type syntax inside
bounded residual state. `acceptsApplication` compares the definition's full trait
application after replacing its abstract target with the requested target.

## Algorithm and invariants

Check canonical target ownership and argument saturation, pair declaration parameters with requested
arguments, and form each record or variant payload type under the declaration's
original names and kinds. Substitute the entire argument vector with the shared
rigid substitution. Reconstruct nominal identities using their actual module
segments, preserving references, tuples, function asyncness, capabilities,
dynamic traits, Never and higher-kind applications. Keep field/variant names, attributes
and authored diagnostic anchors. The prepared shape's bound parameters are the
request's parameters; concrete external requests introduce no leftover binders.
Canonical generated type nodes use request-owned identity and depth/node limits.

## Negative logic and edge cases

No source-string parsing, basename alias resolution, inference variables, poisoned
types or guessed constructor identity. Refuse an unrepresentable applied head or
function default-arity contract rather than silently dropping it. Record and Sum
payload forms retain their declaration order and named/positional distinction.
A differently applied trait cannot select a strategy merely by sharing its owner.
This module publishes no implementation and proves no field capability.

## Grill Log

- **Q:** Keep generic declaration parameters for a concrete alias request?
  **A:** Replace the field types and retain only actual request binders.
  _Rejected:_ an unused impl parameter or a field left as the declaration's A.
- **Q:** Rewrite canonical type names as text and reparse them? **A:** Construct
  ordinary syntax directly from formed types and module segments. _Rejected:_
  quoted-source generation, fabricated offsets and loss of capability metadata.
- **Q:** Accept every application of one trait? **A:** Compare full applications
  after simultaneous target substitution. _Rejected:_ owner-only matching.

## Linkage and references

Requires [[Derive Catalogue]], [[Derive Residual State]], [[Type Formation]],
[[Type Substitution]] and [[Syntax Tree]]. Referenced by [[Derive Design]] ·
[[src/_MOC]].
