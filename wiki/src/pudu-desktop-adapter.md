---
type: module
path: "@root/cbits/pudu_desktop.m"
fidelity: Active
tags: [module, runtime, ui, macos]
aliases: [Pudu Desktop Adapter]
---

# Pudu Desktop Adapter

## Purpose and interface

Implement the private macOS side of [[Eval Desktop]] using public AppKit and CoreGraphics entry
points. It creates one ordinary titled window with a custom bitmap view, copies an admitted opaque
RGBA frame for drawing, pumps the application event queue for a bounded interval, reports a close
request, and releases the window. While pumping it records presses, scrolls, named keys (next,
previous, activate, dismiss, erase), printable text, Command/Control chords, and resizes as
tab-separated lines in a bounded queue that `pudu_desktop_inputs` drains, plus `down`, `move`, and
`up` records with millisecond timestamps for the primary button. `pudu_desktop_clipboard_read` and
`pudu_desktop_clipboard_write` read and replace the general pasteboard's plain text. Key presses are consumed
rather than forwarded, so an unhandled key never plays the system alert. The adapter is compiled only for macOS.

The adapter is not a Pudu foreign-library integration: application source cannot import it, name
its symbols, hold platform object values, or select its ABI. It is target runtime plumbing analogous to
the process and filesystem implementations.

## Invariants

- Calls fail off the main thread.
- Frame length equals width times height times four before any platform object reads it.
- The view owns a copy of frame bytes across asynchronous drawing.
- Close detaches the delegate and orders the window out before release.
- Queued input stops growing past one mebibyte until drained.
- Platform exceptions are contained and returned as failure status.

## Grill Log

- **Q:** Use a declarative platform framework, a GPU view kit, or a third-party media library for the first window? **A:** No. _Rationale:_ the
  requirement is a minimal language-owned native presenter and those would introduce a framework
  model or third-party toolkit above the OS boundary. _Accepted:_ AppKit window/event services plus
  CoreGraphics bitmap presentation.
- **Q:** Start with Metal? **A:** No. _Rationale:_ the first acceptance question is whether Pudu's
  exact reference surface reaches a real window with correct ownership. Metal follows behind the
  same contract with frame-pacing and percentile gates. _Rejected:_ coupling the application API to
  the first accelerated backend.

## Referenced by

[[Eval Desktop]] · [[Native Application UI]]
