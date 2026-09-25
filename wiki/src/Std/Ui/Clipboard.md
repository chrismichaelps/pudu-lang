---
type: module
path: "@root/lib/Std/Ui/Clipboard.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, clipboard]
aliases: [Std Ui Clipboard]
---

# Std Ui Clipboard

## Purpose and interface

The system clipboard's text: `read() -> Result[Str, ClipboardError]`, `write(text)`, `explain`, and
`type ClipboardError = NoText | UnsupportedPlatform | PlatformFailure(Str)`.

## Semantics

- `NoText` distinguishes a clipboard holding an image or nothing from one holding empty text.
- Targets without a clipboard adapter answer `UnsupportedPlatform`; a silent no-op is forbidden.

## Grill Log

- **Q:** Does a test write the real clipboard? **A:** Only when a run sets
  `PUDU_DESKTOP_DRIVE=1`, and then it restores what was there: the clipboard belongs to the person
  using the machine. _Rejected:_ writing it on every test run.

## Dependencies and consumers

- Depends on the prelude `desktopClipboardRead` and `desktopClipboardWrite` effects ([[Eval Desktop]]).
- Consumed by editors and fields offering copy and paste through [[Std Ui Keymap]] chords.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
