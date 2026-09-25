---
type: module
path: "@root/lib/Std/Ui/History.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, undo]
aliases: [Std Ui History]
---

# Std Ui History

## Purpose and interface

Undo and redo over whole states. Because states are immutable values with structural sharing, a
history of states costs what changed, and undo is always correct without inverse operations.

Exports: `type History[S]`, `start(present, limit)`, `record`, `amend`, `undo`, `redo`, `presentOf`,
`canUndo`, `canRedo`, `depth`.

## Semantics

- `record` pushes the present, drops the redo stack, and keeps at most `limit` earlier states; an
  equal state records nothing.
- `amend` replaces the present without a step, which is how typing a word becomes one undo.
- Undo or redo with nothing to move is the unchanged history, never a failure.

## Grill Log

- **Q:** Command objects with inverse actions? **A:** No. _Rationale:_ an inverse written by hand is
  a second implementation of every edit and drifts from the first; whole-state snapshots are exact
  and cheap with persistent collections. _Rejected:_ an undo manager of registered closures.

## Dependencies and consumers

- No dependencies.
- Consumed by editors and forms together with [[Std Ui Keymap]] undo/redo chords.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
