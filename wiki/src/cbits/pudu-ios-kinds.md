---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_kinds.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Kinds, pudu-ios-kinds]
---

# pudu-ios-kinds

## Purpose and interface

Private kind table of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private
headers ([[Native Toolchain Host Sources]]). The table was defined in `pudu_ios_host.m`; it now lives in this header so
the host main file stays under 500 lines. The table maps each control kind code of [[Std Mobile Stream]] to the hooks that
create, configure, self-test and style it. It carries no platform code of its own: every entry names functions defined
in the headers the host includes.

The header provides:
- `PuduKind`: a struct of the hook fields listed below.
- `pudu_kind_table`: a constant array of `PuduKind`, indexed by kind code, one entry for each code from 1 to 21.

Hook fields of each entry:

| Field | Holds |
| --- | --- |
| factory | the function that makes the control; list, toggle, label and button factories are in [[iOS Host Controls]] and [[iOS Host List]], value factories in [[pudu-ios-values]] |
| text, hint, state | the setter for TEXT, HINT and STATE, or none |
| number | the setter for VALUE on a kind that takes a number or an index, or none |
| bounds | the setter for BOUNDS, or none |
| options | the setter for OPTIONS, or none |
| choosing | whether VALUE is an index bounded by the option count |
| control | the control that carries tag and accessible name |
| children | the stack accessor for children, when the kind has them |
| fill, press | the self-test hooks that type into or tap the control |
| shown | the self-test report hook |
| drive | the self-test hook of the value controls self-test in [[pudu-ios-values]] |
| paint, style | the hooks that apply a color role or a text style, from [[iOS Host Theme]] |
| inked | whether the kind takes Ink without an explicit COLOR |

## Behavior

- `pudu_ui_apply` reads a node's kind from the node table and looks the kind up in `pudu_kind_table`.
- An entry field that is empty means the kind does not accept that instruction. The dispatcher refuses the instruction as
  a stream defect; it never falls back to another entry.
- The table is `const` and is never written at run time.
- The value kinds 12 to 21 use the same fields as the earlier kinds. A value kind with a number setter accepts VALUE;
  a value kind without one refuses it.

## Invariants

- One entry per kind code, and the array index equals the kind code. Code 0 is unused.
- Each entry is a designated initializer that names every field it sets. Fields not named read as zero, which the
  dispatcher treats as absent.
- An entry names only functions that exist in the included headers; the table adds no new platform calls.
- `choosing` is set only on kinds whose VALUE is an index: segments and wheel.

## Negative Logic

- No stream reading. [[iOS Host Stream]] decodes words and calls the handlers.
- No platform call in the table itself.
- No refusal logic. Refusals are made by the handlers the entries name, not by the table.
- No kind beyond 21 is defined here; a new kind is added with the instruction that creates it.

## Dependencies and consumers

Depends on [[iOS Host Controls]], [[iOS Host List]], [[iOS Host Theme]], [[iOS Host Material]], [[pudu-ios-values]] for
the value factories and handlers, and [[pudu_ios_nodes.h]] for the kind codes. Included by [[iOS Host Adapter]], which
reads `pudu_kind_table` for every CREATE, VALUE, BOUNDS, OPTIONS, COUNT and MOMENT. The program side is
[[Std Mobile Control]] and [[Std Mobile Stream]].

## Resolved Grill Log

- **Q:** Why move the table out of the host? **A:** The host main file reached its 500-line budget. The table is a
  separate responsibility from reading the stream, and the value controls add eleven entries. _Rejected:_ shrinking the
  host by compacting its entries onto fewer lines.
- **Q:** Why designated initializers? **A:** Each entry names its hooks, so a field added to `PuduKind` does not shift
  the entries that follow, and a hook left out of an entry is visibly absent rather than read from a neighbouring entry.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host Controls]] · [[pudu-ios-values]] · [[pudu-ios-host]] · [[Std Mobile Control]] · [[Native Value Controls Delivery]]
