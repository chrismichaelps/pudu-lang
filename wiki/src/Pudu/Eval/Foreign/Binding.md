---
type: module
path: "@root/src/Pudu/Eval/Foreign/Binding.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime]
aliases: [Eval Foreign Binding]
---

# Eval Foreign Binding

## Purpose and interface

Own ForeignBinding, ForeignSlot, ForeignClaim and ForeignRelease with their
existing fields, strictness, Eq and Show instances. Eval.Value re-exports them.
This vocabulary describes native argument/result crossings, ownership generation
and borrowed claims, retained release symbols, and output slots.

## Algorithm and negative logic

Records and closed data constructors only. No IO, interpretation, claiming,
validation, or native dispatch occurs here; no field changes accompany extraction.

## Dependencies and consumers

Requires Data.Text and [[Foreign Crossing]]. Consumed by [[Eval Value]] and through
its unchanged exports by the runtime's foreign dispatch modules.

## Grill Log

Resolved: extracting independent foreign metadata avoids expanding Eval.Value
past its size target for MultiMap storage. Keep exports and all field semantics
unchanged; do not split recursive Value/OrdValue definitions or add orphan instances.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[src/_MOC]] · [[Eval Value]]
