---
type: module
path: "@root/test/Pudu/Backend/GenericPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Generic Programs]
---
# Backend Generic Programs

Exports genericSuccessPrograms (label, source, expected stdout) and
genericRefusalPrograms (label, source), for [[Native Generics]].

Resolved Grill Log: the successes run one generic function at several types
and nested in itself, build, read, update, compare, match and render generic
records at two argument types, call bounded generics that reach inherited
defaults and generic implementations (including a bounded generic calling
another), and recurse over a generic sum. The refusals fail inside a copy and
inside a default reached through a bound, each at its own source.

[[Backend Module Programs]] runs them and [[Backend Text Leak Tests]] counts
the successes' allocations.

## Referenced by

[[Native Generics]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
