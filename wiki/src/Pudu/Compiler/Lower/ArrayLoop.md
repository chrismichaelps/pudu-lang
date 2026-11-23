---
type: module
path: "@root/src/Pudu/Compiler/Lower/ArrayLoop.hs"
fidelity: Active
aliases: [Compiler Lower Array Loop]
---
# Compiler Lower Array Loop

Lower array and range traversal after the receiver and supplied
operands have been captured. Map and filter accumulate an array,
reduce threads its accumulator, and sort follows the existing run
and merge order. Join walks selected text payloads.

## Resolved Grill Log

The callback runs only on a visited item or comparison. Failure to
call its held value follows the runtime protocol. An array predicate
must yield Bool. A range filter accepts only true and discards other
returned values after their effects. An empty collection never
validates a callback result or reports an invocation failure.

## Dependencies and consumers

[[Compiler Lower Array]] · [[Compiler Lower Sort]] ·
[[Compiler Lower Arguments]] · [[Compiler Lower Dynamic]] · [[Core IR]]

## Referenced by

[[Compiler Lower Array]] · [[Program Compiler Module Map]]

## Callback arity and defaults

Resolved Grill Log: selected callable signatures separate written
parameters from the hidden supplied count. Omitted parameters use
the existing callee default prologue. Wrong arity uses the selected
parameter name and the traversal invocation span.
