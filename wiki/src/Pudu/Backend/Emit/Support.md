---
type: module
path: "@root/src/Pudu/Backend/Emit/Support.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Support]
tags: [module, backend, codegen]
---
# Backend Emit Support

## Purpose

Own pure runtime-part selection, function signatures and wrappers, and C scalar/name spelling.

## Interface

Exports runtimeNeeds, entryResultType, functionPrototype, wrapperFor, functionSymbol, functionSymbolByName, wrapperSymbol, returnTypeFor, integerKindOfExpression, integerLiteralText, declaration, declarationFor, localSymbol, and comment.

## Algorithm and invariants

The runtime walk unions every operation requirement. All reachable non-entry functions receive wrappers; reachability guarantees each is called. Names encode every Unicode scalar as hexadecimal followed by an underscore, providing an injective ASCII spelling even for underscores and non-ASCII names. Integer constants preserve INT64_MIN. Wrappers check depth before the call and restore it after every normal result.

## Negative logic

No frontend or evaluator dependencies, IO, environment reads, or semantic inference.
Only lowered Core IR reaches this boundary. Source text never becomes executable C.

## Dependencies and consumers

Uses [[Pudu Core]], [[Integer Literal]], and [[Backend Emit State]]. Consumed by [[Backend Emit]].

## Grill Log

- **Q:** Why extract this responsibility? **A:** It has a stable pure interface and keeps the emitter below 500 lines. The split preserves output ordering and diagnostic geometry. Rejected: a single growing emitter.
- **Q:** May extraction change semantics? **A:** No; eager evaluation is sequenced by the emitter, while this module supplies representation and assembly primitives. Rejected: backend inference.

## Referenced by

[[Backend Emit]] · [[src/Pudu/Backend/_MOC]]

## Resolved control-flow traversal (#489)

Runtime requirements visit both loop conditions and bodies and every break operand. Never is representation-free at the public function boundary and uses an initialized dummy integer only in unreachable scalar sequencing; no ownership-bearing value is admitted.

- **Q:** Can breaking with a discarded checked value omit its helper? **A:** No; the runtime walk includes the operand even when no result slot exists. Rejected: visiting only value-producing consumers.
