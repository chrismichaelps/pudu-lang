---
type: module
path: "@root/cbits/pudu_desktop_access.m"
fidelity: Active
tags: [module, runtime, ui, macos, accessibility]
aliases: [Pudu Desktop Access]
---

# Pudu Desktop Access

## Purpose and interface

Expose a window's content to macOS assistive clients from the snapshot the program presents.
`pudu_desktop_accessibility(handle, records, length)` reads [[Std Ui Accessible]] records and
replaces the frame view's accessibility children with one `NSAccessibilityElement` per record:
role, label, focus, and parent. Each element keeps its frame in top-left content coordinates and
converts it to the screen through the view whenever it is asked, so the frame an assistive client
reads follows the window when it moves. `pudu_desktop_accessibility_report(handle, buffer,
capacity)` answers what AppKit itself reports for those elements, as records in the same form,
measured and then copied like the input queue.

| Layout role | Platform role |
| --- | --- |
| group | `AXGroup` |
| heading | `AXHeading` |
| label | `AXStaticText` |
| image | `AXImage` |
| button | `AXButton` |
| toggle | `AXCheckBox` |
| field | `AXTextField` |

## Invariants

- A snapshot is read completely before anything is replaced; a malformed one answers `-3` and the
  window keeps the tree it had.
- A parent must be a record already read, so every element is built under an existing one and no
  cycle can be expressed. A node read twice, an unknown role, or a negative width or height is
  refused the same way.
- The frame view is the window's first responder and names the focused element as its focused
  accessibility element, so the application's focused element, which VoiceOver's cursor follows, is
  the focused control rather than the window.
- The report walks what AppKit answers (`accessibilityChildren`, `accessibilityRole`,
  `accessibilityLabel`, `accessibilityFrame`, `isAccessibilityFocused`), not the stored records, and
  converts screen frames back to top-left content coordinates.
- A layout-changed notification is posted after each replacement so a running screen reader
  re-reads the window.
- Calls fail off the main thread; platform exceptions are contained and answered as `-4`.

## Grill Log

- **Q:** Add the elements to `pudu_desktop.m`? **A:** No. _Rationale:_ the adapter is already near
  the file-size limit and accessibility is a separate responsibility. _Accepted:_ a second
  translation unit that reaches the window's view through [[Pudu Desktop Host]].
- **Q:** Store absolute screen frames? **A:** No. _Rationale:_ they go stale when the window moves
  and nothing re-presents. _Accepted:_ an element subclass that converts its content frame through
  the view on every query. _Rejected:_ `accessibilityFrameInParentSpace`, whose meaning for an
  element nested under another element is not documented.
- **Q:** Prove the export with a screen reader driven from outside? **A:** Not as the gate.
  _Rationale:_ reading another process's accessibility tree needs the assistive-access permission,
  which a test cannot grant itself. _Accepted:_ the report reads AppKit's own answers in-process;
  an out-of-process read through the system accessibility API is a manual check on a machine that
  grants it. That check found the application's focused element was the window, because the view
  was never first responder.

## Referenced by

[[Eval Desktop]] · [[Pudu Desktop Header]] · [[Pudu Desktop Host]] · [[Pudu Desktop Adapter]] · [[Std Ui Accessible]] · [[src/cbits/_MOC]]
