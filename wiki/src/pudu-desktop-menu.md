---
type: module
path: "@root/cbits/pudu_desktop_menu.m"
fidelity: Active
tags: [module, runtime, ui, macos, menus]
aliases: [Pudu Desktop Menu]
---

# Pudu Desktop Menu

## Purpose and interface

Make a program's [[Std Ui Menu]] bar the application's menu bar. `pudu_desktop_menu(handle,
records, length)` reads `Menu.native` records and replaces `NSApp.mainMenu`: first an application
menu holding "Quit" (which requests the window close), then one `NSMenu` per top-level menu with its
commands, separators, and submenus. Choosing a command queues `menu` and its name in the window's
input records. `pudu_desktop_menu_report(handle, buffer, capacity)` writes the installed bar back as
records of the same form, read from the `NSMenuItem`s, measured and then copied like the input queue.

A command whose chord holds Command or Control and ends in one character shows that key equivalent,
with its modifiers. Other chords are shown by no equivalent; the program still receives them as
shortcuts.

## Invariants

- Every record is read before the bar is replaced; a malformed one answers `-3` and keeps the bar.
  Only a `menu` may sit at depth 0, and an item's depth may be at most one deeper than the menu
  that holds it.
- A key equivalent never fires the command twice: the adapter consumes Command and Control key
  presses as chords before AppKit's menus see them, so a chord arrives once, as a shortcut.
- Menu items target an object the window host retains; closing that window clears the menu bar.
- AppKit adds items of its own (Writing Tools, AutoFill, Dictation, Emoji & Symbols) to a menu
  titled Edit. Every item the adapter builds carries one identifier, and the report lists only
  those, so it shows what the program installed.
- Calls fail off the main thread; platform exceptions are contained and answered as `-4`.

## Grill Log

- **Q:** Let a key equivalent run the command through the menu? **A:** No. _Rationale:_ the chord
  already arrives as a shortcut; letting AppKit also fire the item would run the command twice.
  _Accepted:_ equivalents are shown, and chords stay the one path.
- **Q:** Offer Quit with ⌘Q? **A:** Quit is shown without an equivalent. _Rationale:_ ⌘Q arrives as a
  chord the program may bind; a Quit item that answered it too would close behind the program.
- **Q:** Report the records the program sent? **A:** No. _Rationale:_ the report exists to show what
  the platform holds. _Accepted:_ records rebuilt from the `NSMenuItem`s.

## Referenced by

[[Eval Desktop]] · [[Pudu Desktop Header]] · [[Pudu Desktop Host]] · [[Pudu Desktop Adapter]] · [[Std Ui Menu]] · [[Std Ui Desktop]] · [[src/cbits/_MOC]]
