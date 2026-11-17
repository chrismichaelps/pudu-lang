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

## Resolved Grill Log for #876 — Interpreter callback values

Each callback slot records its owner, both native positions and the
trampoline signature. The corresponding context parameter consumes no
Pudu argument.

## Resolved Grill Log for #877 — Foreign loan settlement

Store declared loan modes by native parameter index. The pointee crossing uses the existing argument kind at that index.

## Resolved Grill Log for #877 — Checked foreign bounds

Retain checked extent relations at native positions so ordinary input order, callback contexts and output slots cannot shift a length's targets.

## Resolved Grill Log for #877 — Interpreter array crossings

The binding maps native array-loan indices to their mutability. The existing argument crossing at that index describes the element type.

## Resolved Grill Log for #877 — Optional handles

Inputs keep the existing optional handle crossing. A result records its null policy independently of its handle carrier and ownership.

## Resolved Grill Log for #877 — Returned run settlement

Keep the returned run contract beside existing result ownership. The ABI pointer carrier identifies the destructor and temporary claim.

## Resolved Grill Log for #877 — Nullable loans

Retain nullable flags by native index beside checked scalar and array loan modes.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[src/_MOC]] · [[Eval Value]]

## Resolved Grill Log for interpreter callback groups

Retain member dispatch signatures and field names in checked order beside a group context slot.

## Resolved Grill Log for group adapter identity

Group contexts and member trampolines share the checked member layout as
part of their adapter identity. Distinct definitions with the same source
name cannot exchange callback contexts in an interpreter process.

## Resolved Grill Log for interpreted Objective-C dispatch

A resolved Objective-C method describes how to find the function and receiver at dispatch.

## Resolved Grill Log for Objective-C delegates

`DelegateBinding` holds the checked class symbol, the group, and the member selectors. Interpreted construction reads it when the constructor runs.
