---
type: module
path: "@root/cbits/pudu_ios_kinds.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Kinds]
---

# iOS Host Kinds

## Purpose and interface

Private instruction and kind codes of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the instruction codes the stream reader dispatches on, the kind codes of every control, the `pudu_kind` record that describes how a kind is built and written to, and the constant kind table. The table was moved out of the adapter so the adapter stays within its line budget as value controls are added.

The record carries a `number` setter for VALUE, beside the text, hint and state setters. VALUE dispatches through the number setter of the node's kind. After `inked`, the record gains four entries: `number` (VALUE), `bounds` (BOUNDS), `options` (OPTIONS) and `drive` (what the controls self-test does to the kind). New kinds use designated initializers; omitted entries are NULL, and a NULL entry means the kind refuses that instruction.

## Behavior

- Instruction codes match [[Std Mobile Stream]]: CREATE 1 through MOVE 12, the theming codes 20 to 23, the list codes 24 and 25, MATERIAL 26, the capability codes 27 to 35, and the value control codes BOUNDS 36, OPTIONS 37, COUNT 38 and MOMENT 39.
- Kind codes match [[Std Mobile Stream]]: the existing kinds 1 to 11 and the value control kinds SLIDER 12 through WELL 21.
- The kind table is indexed by kind. Each entry names the factory, the setters it accepts (text, hint, state, number), the control that carries tag and accessible name, the stack accessor for children when present, the paint and style hooks, and the self-test actions.
- A kind whose table entry omits a setter refuses the instruction that needs it. No entry is ignored.

## Invariants

- A kind's `number` setter is set only for a kind that takes a number. A VALUE on any other kind is a stream defect.

## Negative Logic

- No behavior. The header defines codes, the record and the table; the factories live in [[iOS Host Controls]] and [[iOS Host Values]].
- No stream reading. The reader is [[iOS Host Stream]].
- No dispatch by kind. Dispatch is by table lookup in [[iOS Host Adapter]].

## Dependencies and consumers

Included by [[iOS Host Adapter]]. Its codes are the host side of [[Std Mobile Stream]] and of the kinds of [[Std Mobile Control]]. The factories it names are in [[iOS Host Controls]], [[iOS Host Values]] and [[iOS Host Text]].

## Resolved Grill Log

- None recorded. The table moved out of the adapter with no change of behavior.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Stream]] · [[Native iOS Controls Delivery]]
