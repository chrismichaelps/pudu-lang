---
type: module
path: "@root/test/qualified-record-methods.mjs"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, semantics]
aliases: [Qualified Record Method Gate]
---
# Qualified Record Method Gate

`node test/qualified-record-methods.mjs <optimized-compiler>` exercises isolated modules exporting
record methods. Module and selected-type imports, direct/retained/generic methods and static
constructors must preserve canonical owner identity and defining captures in both evaluators,
including cold/warm product reuse. Wrong receiver/result types, missing/private members,
lexical shadows and ambiguity must be positioned refusals. Scratch files are always removed;
subprocesses have deadlines. Preserve original diagnostic/output oracles in the full suite.

Resolved Grill Log: assert observable output and refusal rather than a specific internal symbol.
Both static admission and runtime execution must succeed before a formerly rejected path ships.
Requires the canonical record-owner partition; no independent trait-provider protocol.

## Referenced by

[[src/_MOC]] · [[Qualified Record Method Delivery]] · [[Type Check Qualified]]
