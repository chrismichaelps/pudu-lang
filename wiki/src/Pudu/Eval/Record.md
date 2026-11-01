---
type: module
path: "@root/src/Pudu/Eval/Record.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, nominal]
aliases: [Eval Record Construction]
---
# Eval Record Construction

## Purpose and interface

recordConstructor :: ModuleName -> [Text] -> ([(Text, Value)] -> Value)
selects immutable construction from executable syntax and authored field labels.
Consumed by [[Evaluator]], [[Eval Compile]] and [[Eval Loop Kernel]]. Requires
[[Eval Value]], [[Syntax Name]], existing containers, list sorting and text.

## Algorithm and invariants

The internal ::sum:: descriptor carries canonical owner, short label and declared
field names. Select NamedSumValue and the order plan before evaluating fields.
If authored labels equal declared labels, reuse the field list directly. Otherwise
prepare declaration ranks once and stably sort completed fields by rank. Unknown
host fields remain after declared ones; do not drop fields or invent values.
Other paths retain ordinary RecordValue and the complete module-name text.

## Negative logic

No environment lookup, basename registry, source AST mutation, evaluation or
missing-field recovery. Earlier checking validates source field shapes. Ordinary
record ordering remains #519; this module publishes only the named-sum policy.

## Resolved Grill Log

Three evaluators must use one constructor/storage policy while each retains its
existing evaluation strategy. A dedicated pure boundary avoids duplicated
canonical descriptor decoding and field-order logic. Sorting follows effects;
canonical identity and display labels remain separate. See [[Named Sum Publication]].

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Named Sum Publication]] · [[Pudu Cabal Manifest]]

## Checked constructor values (#766)

The exact ::constructor::/owner/label descriptor with no fields produces SumValue owner label []. All three evaluators consume the existing projected construction path without looking up a bare alias. The internal descriptor cannot be authored; normal named/ordinary record policies remain unchanged.

Resolved Grill Log: checked canonical identity must survive lowering even when a type and a bare variant share text. No runtime owner inference or source syntax change. See [[Variant Namespace Delivery]].
