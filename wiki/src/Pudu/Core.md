---
type: module
path: "@root/src/Pudu/Core.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Pudu Core IR Module]
---
# Pudu Core

The typed, source-located data contract for native lowering and emission.
This partition registers the model only; it adds no native command or execution
path. It projects the existing completion branch's declarations unchanged.

CoreModule owns functions, canonical layouts, entry identity and closure facts.
CoreFunction/Parameter/Local carry checked types and stable local identities.
CoreBlock/Statement/Expression retain source spans, ordered operations and
explicit control targets. CoreLoopId separates source labels from generated IDs.
CoreType includes scalar, nominal, collection, callable, unit and Never forms;
closed operator/method enums select semantics without target-language spelling.
CoreLayout/Variant/Arm/Pattern retain declaration order, payload structure,
bindings, guards and pattern alternatives. CoreClosureInfo records capture
types, display/site identity, builtin classification and hidden environments.

coreTypeName recursively renders source-facing type names. displayName removes
canonical module qualification for display; nominal identity remains qualified
in the data and participates in equality. Type arguments retain their order.

## Resolved Grill Log

- No inference, validation, IO, C syntax or runtime execution belongs here.
  Lowering must establish the facts these records carry; constructors alone
  are not a proof that arbitrary hand-built IR is well formed.
- Keep Integer payloads exact and retain canonical owners behind display names.
- CorePrint is effect-only legacy IR; source output Results cannot escape as unit.
- Explicit callable flags are independent; do not infer policy from names/captures.
- This is a review partition of #486, not a native coverage or readiness claim.

## Referenced by

[[src/_MOC]] · [[Native Core Contracts Delivery]] · [[Core IR]]
