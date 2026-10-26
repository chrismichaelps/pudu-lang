---
type: module
path: "@root/test/Pudu/Backend/MethodPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Method Programs]
---
# Backend Method Programs

Exports methodSuccessPrograms (label, source, expected stdout) and
methodRefusalPrograms (label, source), for [[Native Trait Methods]].

Resolved Grill Log: the successes cover members and inherited defaults on
records and sums, a default calling the implementation's override,
type-qualified, trait-qualified and static members, implementations on `Int`
and `Str` beside Str's built-in methods, `toText()` on every kind of value
with a type's own `toText` winning, and recursion and `Self` results. Order
cases check that arguments print before the receiver, that an argument
reassigning the receiver's variable is seen, and that a returning argument
stops the call before the receiver runs. The refusals are runtime failures
inside a method and inside an inherited default, which must report at their
own source.

[[Backend Module Programs]] runs them in its whole-program harness and
[[Backend Text Leak Tests]] counts the successes' allocations.

## Referenced by

[[Native Trait Methods]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
