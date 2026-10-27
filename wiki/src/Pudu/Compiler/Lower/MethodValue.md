---
type: module
path: "@root/src/Pudu/Compiler/Lower/MethodValue.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Method Value]
---
# Compiler Lower Method Value

Export lowerMethodValue. For a member expression on a text, array, map, set,
range, char or bytes receiver whose fact is a function type, lower the
receiver once and answer a closure over it. The lifted body, keyed by method,
receiver type and signature, declares `$receiver` from capture 0 and lowers
`$receiver.member($1, ...)` through the ordinary call dispatch. The call span
is re-faced to the method's result and each argument gets a span past the
end of the source with its parameter's fact; the overlay is dropped after.

## Resolved Grill Log

No method is implemented twice. Refusals raised inside the body point at
made-up spans, so they are replaced by one refusal at the member expression.
Closure info records the receiver type, which drives rendering, equality and
the caller-blaming frame flag. See [[Native Method Values]].

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]]
