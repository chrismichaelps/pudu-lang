---
type: module
path: "@root/src/Pudu/Compiler/Lower/Reference.hs"
fidelity: Planned
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Reference]
---
# Compiler Lower Reference

## Purpose and interface

Planned compiler-owned identity lowering under [[Native Shared References]].
Export lowerReference with the body's expression callback, LowerState, complete
operator Span, operator Text and located operand, returning the ordinary
LowerState/optional CoreExpression-and-type result.

## Resolved Grill Log

- Lower the operand once. A Never operand preserves its transfer directly.
- Reject expressionIsPrintValued before returning a carrier: CorePrint's unit
  cannot stand for the actual Result value of print.
- `&` requires sharedReferenceTarget at the whole operation span to match the
  lowered operand's represented type. `*` requires sharedReferenceTarget at
  the operand span and the solved result type at the operation span to match.
- sharedReferenceTarget inspects the actual ReferenceTypeValue False in exact
  TypeInfo facts; an erased Core type or equal offsets cannot prove a reference.
- Preserve the operand's Core expression and span, without a C pointer, copy
  instruction, wrapper value or fabricated runtime operation. Existing frame
  ownership handles any retained text/aggregate value.
- Mutable references and &mut remain refused until call/place writeback exists.
  Missing facts and mismatched carriers refuse at the operator with E6001.

## Dependencies and consumers

[[Compiler Lower Types]] · [[Compiler Lower Control]] · [[Compiler Lower State]] ·
[[Compiler Lower Scalar]] · [[Core IR]] · [[Native Shared References]]

## Referenced by

[[Native Shared References]] · [[Compiler Lower Scalar]]
