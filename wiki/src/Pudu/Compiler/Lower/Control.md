---
type: module
path: "@root/src/Pudu/Compiler/Lower/Control.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower Control]
---

# Compiler Lower Control

## Fixed signed admission (#497)

Allow nativeScalarType break operands alongside explicit Never. Canonical kind
equality continues to govern joins; no widening or retagging occurs. Resolved
Grill Log: preserve condition scope, destination identity, ordered break effects
and print Result guards while carrying new integer kinds unchanged.

## Purpose and interface

Own loop targets, transfer lowering, scalar break joins, direct block divergence,
and detection of print results that cannot escape the effect-only Core encoding.
`lowerWhile`, `lowerLoop`, and `lowerTransfer` take the traversal callbacks from
[[Compiler Lower Body]], keeping recursion explicit without module cycles.
`blockType` and `joinType` preserve Never; `printValued` and
`expressionIsPrintValued` inspect value-producing paths.

## Algorithm and invariants

[[Compiler Lower State]] resets loop IDs and nearest-first frames per function.
Labels resolve to the nearest matching frame; unlabelled transfers use the head.
While conditions lower before pushing that while frame. A frame collects only
reachable scalar/unit break operand types; Never operands transfer before their
own break and contribute no type. A loop without an observed local break is
Never. While values are unit and discard body results. Break operands lower
before their destination frame is updated, preserving nested transfers to the
same or outer targets. Print-valued break operands refuse E6001 because their
actual Result cannot become unit. Unsupported text/aggregate loop results
refuse at their source span. Blocks without results become Never only when a
direct return/break/continue, Never evaluation, or Never condition proves divergence. A statement if with ordinary condition remains unit even when both branches transfer.

## Negative logic

No source label enters Core. No semantic checking, C emission, hidden fallback,
or fabricated unit literal. Traversal remains in Body; state remains in State.

## Dependencies and consumers

[[Compiler Lower Body]] · [[Compiler Lower State]] · [[Pudu Core]] · [[Frontend Syntax]].

## Grill Log

- **Q:** How does the split avoid circular traversal modules? **A:** Body passes expression/block callbacks to this bounded control-flow responsibility. Resolved; rejected a module cycle or oversized traversal.
- **Q:** Can a nested transfer lose its destination state? **A:** The operand is lowered first and the target frame updated in that resulting state. Resolved; rejected restoring a stale frame stack.
- **Q:** Can print's unit-shaped Core escape through break? **A:** No; recursively print-valued operands refuse. Resolved; rejected Result erasure.
- **Q:** Does every loop body's result become a loop result? **A:** No; only break values determine loop results, and every body result is evaluated then discarded. Resolved; rejected body-type inference.

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower State]] · [[Compiler Lower]] · [[src/Pudu/Compiler/_MOC]]

## Never operand admission (#489)

Resolved Grill Log: Never operands are admitted in scalar expected contexts
without retagging their Core type or inventing an inhabited value. Eager unary,
binary and call expressions remain Never when an operand cannot return; logical
right operands remain guarded and therefore do not make the whole expression
Never. A Never condition makes its conditional Never. Never initializers bind
a Never local, and Never assignments and return operands retain their transfer.
Result-valued print expressions remain effect-only: bindings, call arguments,
explicit returns, break operands and function results cannot erase their carrier.
A divergent block's unreachable trailing print does not produce a value.

## Platform Int operators (#495)

CoreComplement is a represented unary scalar; expressionIsPrintValued keeps its existing total default and never invents a print carrier. No source change unless exhaustive compiler matching requires one.

Resolved Grill Log: use defined unsigned bit patterns, validate counts before shifts, and prove signed arithmetic bounds before evaluation. The actual interpreter determines results, effect order and exact diagnostic vocabulary. No syntax or type-inference change.
