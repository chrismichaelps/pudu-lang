---
type: module
path: "@root/src/Pudu/Frontend/Syntax/Pattern.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Syntax Pattern Bindings]
---
# Syntax Pattern Bindings

Export `patternBindings :: Located Pattern -> [Located Text]`. Enumerate the
bindings one successful pattern path introduces, retaining source order and
locations, including record shorthand and array rest. An alternative exposes
its first branch's names; [[Resolve Bindings]] validates that every other
branch introduces the same set. Empty and invalid patterns yield no names.

Resolved Grill Log: syntax enumeration owns neither scope nor types. Retain
repeated names within one branch so resolution still reports E2001. Do not
concatenate alternative branches as though both ran. Shared by resolution and
typing; no dependency beyond syntax and text.

## Referenced by

[[src/Pudu/Frontend/Syntax/_MOC]] · [[Resolve Bindings]] · [[Type Check Pattern]]
