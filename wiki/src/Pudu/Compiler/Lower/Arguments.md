---
type: module
path: "@root/src/Pudu/Compiler/Lower/Arguments.hs"
fidelity: Active
aliases: [Compiler Lower Arguments]
---
# Compiler Lower Arguments

`callWithRuntimeArguments` retains the receiver and supplied
arguments in source order before checking their held layouts.
Compatible alternatives feed the operation through their exact slots.
Incompatible alternatives produce the call's runtime diagnostic.

## Resolved Grill Log

An argument that transfers control prevents the call and its argument
diagnostic. A wrong held type does not suppress effects in later
arguments, since invocation validates the complete argument vector.

## Dependencies and consumers

[[Compiler Lower Dynamic]] · [[Compiler Lower State]] · [[Core IR]]

## Referenced by

[[Compiler Lower Text]] · [[Compiler Lower Bytes]] · [[src/Pudu/Compiler/_MOC]]

## Primitive arguments and failure attribution

Resolve slots for a complete argument vector. Direct calls report at
their written invocation. Stored callables report through the frame's
caller. Text-view and byte construction share this rule with methods.

Resolved Grill Log: validate arity after any transfer and before selecting
slots. Keep the diagnostic expression independent of the result carrier.

## Integer operand selection

An operation's integer slot can accept any held integer carrier. Exact
slots still require their named layout. Integer comparison preserves
the mathematical value across widths. Consumers choose when conversion
is guarded and when bounds may clamp to the native position carrier.

Resolved Grill Log: never substitute a narrower value before an
operation validates a relationship between two original operands.

## Collection argument slots

Resolved Grill Log: an unconstrained value passes in its held layout.
A shape slot selects an eligible held receiver-independent argument.
Array method positions and store keys wrap through the platform word
when the evaluator converts them before indexing.

## Traversal operand transfers

Resolved Grill Log: the shared stopping block evaluates the supplied
prefix and exits before traversal if the last operand transfers.
