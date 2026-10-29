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
`up` records with millisecond timestamps for the primary button, and `menu` records for commands
chosen from the menu bar [[Pudu Desktop Menu]] installs. Closing a window that installed the bar
clears it. `pudu_desktop_clipboard_read` and
`pudu_desktop_clipboard_write` read and replace the general pasteboard's plain text. Window state arrives as records too:
`scale\t<millis>` carries the backing scale factor times one thousand once at open and whenever
it changes, `focus\t<0|1>`, `minimize\t<0|1>` and `fullscreen\t<0|1>` follow key, miniaturize
and full-screen transitions. `pudu_desktop_configure(handle, density, minWidth, minHeight,
maxWidth, maxHeight, aspectWidth, aspectHeight, fullscreen)` sets how many frame pixels make one
point (in thousandths; 1000 is the default one-to-one), content size limits in points (zero
means unlimited), an optional content aspect ratio (zero clears it) and the requested
full-screen state. Present sizes the content in points as frame pixels divided by that density,
so a caller drawing at backing resolution gets a sharp image at the same window size. Key presses are consumed
rather than forwarded, so an unhandled key never plays the system alert. The frame view answers assistive clients with the children [[Pudu Desktop Access]] builds. The adapter is compiled only for macOS.

The adapter is not a Pudu foreign-library integration: application source cannot import it, name
its symbols, hold platform object values, or select its ABI. It is target runtime plumbing analogous to
the process and filesystem implementations.

## Invariants

- Calls fail off the main thread.
- Frame length equals width times height times four before any platform object reads it.
- RGBA rows run from the top of the surface downward. PuduFrameView retains the default
  unflipped NSView coordinates; CGContextDrawImage draws without an additional Y inversion.
  Input/accessibility coordinate conversions remain unchanged.
- The view owns a copy of frame bytes across asynchronous drawing.
- Close detaches the delegate and orders the window out before release.
- Queued input stops growing past one mebibyte until drained.
- Configure refuses a density below 250 or above 8000 thousandths, negative limits, a minimum
  above a nonzero maximum, or a half-specified aspect ratio before touching the window, and
  toggles full screen only when the requested state differs from the window's; the transition
  completes asynchronously and is reported by its record, never awaited by spinning.
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

## Presentation regression (#724)

[[Desktop Presentation Test]] draws the real view in a bitmap graphics context, checking exact
asymmetric rows/channels at normal size, resized logical bounds and 2x backing scale, plus empty
frame black fill. The original unconditional Y transform reverses rows and must fail this gate.
[View coordinates](https://developer.apple.com/documentation/appkit/nsview/isflipped) document the
default unflipped view. Native pixels and actual window evidence establish the implementation result.

Resolved Grill Log: preserve the default view geometry and remove only the redundant bitmap
inversion, rather than altering input/accessibility conventions or changing the portable renderer.
## Game input records (#673)

Besides the interface records, the adapter writes a layout-independent channel for games:
`keydown\t<code>\t<repeat>` and `keyup\t<code>` with W3C UI Events `KeyboardEvent.code` names
from a complete table of macOS virtual key codes (modifier transitions come from flag changes,
told left from right by device-dependent bits); `hover\t<x>\t<y>` for pointer motion with or
without a button (the window accepts mouse-moved events); and `button\t<n>\t<down|up>\t<x>\t<y>`
with 0 primary, 1 secondary, 2 middle. Existing records are unchanged, and `Std.Ui` decoding
already skips records it does not know. Grill Log — **Q:** Reuse the interface key names? **A:**
No; they are intents (`activate`, `dismiss`), not keys, and depend on modifiers. Physical codes
make bindings mean the same key on every layout.

## Presentation regression (#724)

[[Desktop Presentation Test]] draws the real view in a bitmap graphics context, checking exact
asymmetric rows/channels at normal size, resized logical bounds and 2x backing scale, plus empty
frame black fill. The original unconditional Y transform reverses rows and must fail this gate.
[View coordinates](https://developer.apple.com/documentation/appkit/nsview/isflipped) document the
default unflipped view. Native pixels and actual window evidence establish the implementation result.

Resolved Grill Log: preserve the default view geometry and remove only the redundant bitmap
inversion, rather than altering input/accessibility conventions or changing the portable renderer.

- **Q:** Infer density from the frame size at present? **A:** No; a frame twice the content
  size is ambiguous between a sharp frame and a requested resize. The caller declares density
  once, and present stays a pure function of the declared density and frame size.
- **Q:** Wait for full-screen transitions inside configure? **A:** No; spinning the event loop
  until the mode changes stalls the frame loop for the whole animation. The record reports the
  completed state and the caller keeps presenting meanwhile.

## Referenced by

[[Eval Desktop]] · [[Native Application UI]] · [[Pudu Desktop Access]] · [[Pudu Desktop Host]] · [[Pudu Desktop Menu]]
