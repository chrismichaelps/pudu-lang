---
type: module
path: "@root/lib/Std/Mobile/Stream.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Stream]
---

# Std Mobile Stream

## Purpose and interface

Pure encoder of the view stream of [[Pudu Native]]. The reconciler in [[Std Mobile View]] decides which changes a commit needs; this module owns how each instruction is spelled as words and bytes. Every function takes the stream so far and answers it extended.

Exports:
- Kinds, values 1 to 11: `LABEL`, `BUTTON`, `COLUMN`, `ROW`, `FIELD`, `TOGGLE`, `SCROLL`, `LIST`, `MATERIAL`, `PROGRESS` (10) and `ACTIVITY` (11). Kinds 7 and 8 use the existing group instructions; a list additionally takes RANGE and COLUMNS. Kind 9 is a container of one child, as a scroll viewport is. Kinds 10 and 11 are leaves, mounted by CREATE and their value instruction. Kinds 12 to 21 are the value controls: `SLIDER` 12, `STEPPER` 13, `SEGMENTS` 14, `WHEEL` 15, `DATE` 16, `TEXT_AREA` 17, `SEARCH` 18, `SYMBOL` 19, `PAGES` 20, `WELL` 21. Each is created by CREATE and takes its values by the instructions below.
- `create(out: Array[UInt8], node: UInt32, kind: UInt32) -> Array[UInt8]`: CREATE, the node and its kind.
- `text(out, node, value: Str) -> Array[UInt8]`: TEXT, the node, then the text.
- `hint(out, node, value: Str) -> Array[UInt8]`: HINT, the node, then the placeholder text.
- `name(out, node, value: Str) -> Array[UInt8]`: NAME, the node, then the accessible name.
- `tag(out, node, value: UInt32) -> Array[UInt8]`: TAG, the node and the tag its events report.
- `state(out, node, on: Bool) -> Array[UInt8]`: STATE, the node and 0 or 1.
- `append(out, parent: UInt32, child: UInt32) -> Array[UInt8]`: APPEND, a group and a child.
- `insert(out, parent, child, index: UInt32) -> Array[UInt8]`: INSERT, a group, a child and the index it takes.
- `move(out, parent, child, index: UInt32) -> Array[UInt8]`: MOVE, a group, a child and its new index.
- `remove(out, node, ids: &Array[UInt32]) -> Array[UInt8]`: REMOVE, the node, the count of ids, then every id of the detached subtree.
- `root(out, node: UInt32) -> Array[UInt8]`: ROOT, the node shown as the screen's content.
- `theme(out, tones: &Array[(UInt32, UInt32, UInt32)]) -> Array[UInt8]`: THEME, the count of tones, then one kind, light word and dark word per role in role order.
- `appearance(out, code: UInt32) -> Array[UInt8]`: APPEARANCE and its code.
- `style(out, node: UInt32, code: UInt32) -> Array[UInt8]`: STYLE, the node and its text style code.
- `color(out, node: UInt32, code: UInt32) -> Array[UInt8]`: COLOR, the node and its role code.
- `range(out, node: UInt32, total: UInt32, first: UInt32) -> Array[UInt8]`: RANGE, the list node, its total item count and the index of its first window row.
- `columns(out, node: UInt32, count: UInt32) -> Array[UInt8]`: COLUMNS, the list node and its column count.
- `material(out, node: UInt32, code: UInt32) -> Array[UInt8]`: SURFACE (code 26), the material node and its material code.
- `gestures(out, node, tag: UInt32, mask: UInt32) -> Array[UInt8]`: GESTURES, the node, the tag its events report and the recognizer mask.
- `alert(out, tag: UInt32, style: UInt32, title: Str, message: Str, choices: &Array[(UInt32, Str)]) -> Array[UInt8]`: ALERT, the tag, the style code, the title and message as text fields, then the choices.
- `value(out, node, permille: UInt32) -> Array[UInt8]`: VALUE, the node and its completion in thousandths.
- `haptic(out, code: UInt32) -> Array[UInt8]`: HAPTIC and its code.
- `traits(out, node, mask: UInt32) -> Array[UInt8]`: TRAITS, the node and its accessibility trait mask.
- `accessHint(out, node, value: Str) -> Array[UInt8]` and `accessValue(out, node, value: Str) -> Array[UInt8]`: ACCESS_HINT and ACCESS_VALUE, the node and its text.
- `menu(out, node, tag: UInt32, choices: &Array[(UInt32, Str)]) -> Array[UInt8]`: MENU, the node, the tag its events report, then the choices.
- `animate(out, node, on: Bool) -> Array[UInt8]`: ANIMATE, the group and 0 or 1.
- `navigate(out, pages: &Array[(UInt32, UInt32, Str)], sheet: Option[(UInt32, UInt32)]) -> Array[UInt8]`: NAVIGATE, the route count, then each route's id, body node and title, then 1 and the sheet's id and body node, or 0.
- `tabs(out, shown: &Array[(UInt32, Str, Str, Array[(UInt32, UInt32, Str)])], selected: UInt32, sheet: Option[(UInt32, UInt32)]) -> Array[UInt8]`: TABS (54), the tab count, then each tab's id, title, symbol and page count, then each page's route id, body node and title; then the selected tab's id, then 1 and the sheet's id and body node, or 0.
- `refresh(out, node, tag, on)`: REFRESH, the scroll or list node, its tag and 1 or 0.
- `fetch(out, generation, method, url, headers: &Array[(Str, Str)], body) -> Array[UInt8]`: FETCH, the generation, the method and URL text fields, the header count, each header's name and value, then the body text. The answer arrives as a FETCHED event.
- `cancel(out, generation) -> Array[UInt8]`: CANCEL and the generation. No answer arrives for it.
- `wake(out, delay: UInt32) -> Array[UInt8]`: WAKE and the delay in milliseconds, replacing any earlier wake. A WOKE event arrives once.
- `number(out, node, value: Int32) -> Array[UInt8]`: VALUE (29), the node and the value as one signed word. A permille written by `value` uses the same code, unsigned.
- `bounds(out, node, low: Int32, high: Int32, step: Int32) -> Array[UInt8]`: BOUNDS (41), the node and three signed words.
- `options(out, node, labels: &Array[Str]) -> Array[UInt8]`: OPTIONS (42), the node, the label count, then each label as a length-prefixed UTF-8 text.
- `pageCount(out, node, count: UInt32) -> Array[UInt8]`: COUNT (43), the node and the page count.
- `moment(out, node, mode: UInt32, seconds: Int64) -> Array[UInt8]`: MOMENT (44), the node, the mode code (0 day, 1 time, 2 day and time), then the seconds high word and low word.

## Images (#973)

- IMAGE (kind 22): an image node. Its CREATE is the kind word, as for the other kinds.
- SOURCE (45): node, origin (0 an asset name, 1 a URL), scaling code (0 Fill, 1 Fit, 2 Stretch), then the location as a length-prefixed text. Exported by the `source` writer.
- The instruction bound was 46 after SOURCE; codes 41 to 45 are BOUNDS, OPTIONS, COUNT, MOMENT and SOURCE.

## System requests (#974)

- OPEN (46): tag, then the URL as a length-prefixed text. Writer `open(out, tag, url)`.
- SHARE (47): tag, then the text. Writer `share(out, tag, message)`.
- COPY (48): the text. Writer `copy(out, clipped)`.
- PASTE (49): tag. Writer `paste(out, tag)`.
- STATUS (50): style code (0 automatic, 1 light text, 2 dark text), then the hidden flag (0 or 1). Writer `status(out, code, hidden)`.
- The instruction bound is now 54. Codes 46 to 50 are OPEN, SHARE, COPY, PASTE and STATUS.

## Permission requests (#976)

- PERMISSIONS (51): a count, then each kind code. Writer `permissions(out, codes: &Array[UInt32])`. The host answers one PERMISSIONED per code, without a prompt.
- PERMISSION (52): one kind code. Writer `permission(out, code)`. The host asks the person when the kind is NotAsked.
- SETTINGS (53): no payload. Writer `settings(out)`. The host opens the application's page in the platform settings.
- Codes 51 to 53 are PERMISSIONS, PERMISSION and SETTINGS. Kind codes are those of [[Std Mobile Permission]].

## Tabs (#977)

- TABS (54): the tab count; per tab its id, title text, symbol text and page count; per page its route id, body node and title text; then the selected tab id; then the sheet flag, followed by the sheet's id and body node when the flag is 1. Writer `tabs(out, shown, selected, sheet)`.
- Byte layout checked by [[Uses Mobile Tabs]]: one tab, one page and no sheet is 47 bytes; the same with a sheet is 55 bytes.
- TABS and NAVIGATE are the two whole-screen instructions. Each replaces the other, and the host closes the one it replaces.
- The instruction bound is now 54.

## Storage (#980)

- STORE_READ (55): tag, place code, then the key as text. Writer `storeRead(out, tag, place, key)`.
- STORE_WRITE (56): place code, the key text, then the value text. Writer `storeWrite(out, place, key, value)`.
- STORE_REMOVE (57): place code, then the key text. Writer `storeRemove(out, place, key)`.
- Place codes: 0 Plain, 1 Secure. The place is written by `Std.Mobile.Storage.placeCode`.
- The instruction bound is now 57.

## Invariants

- Every word is a little-endian 32-bit unsigned value. Every instruction begins with its code word (CREATE 1, TEXT 2, APPEND 3, ROOT 4, TAG 5, STATE 7, HINT 8, NAME 9, INSERT 10, REMOVE 11, MOVE 12, THEME 20, APPEARANCE 21, STYLE 22, COLOR 23, RANGE 24, COLUMNS 25, MATERIAL 26, GESTURES 27, ALERT 28, VALUE 29, HAPTIC 30, TRAITS 31, ACCESS_HINT 32, ACCESS_VALUE 33, MENU 34, ANIMATE 35, NAVIGATE 36, REFRESH 37, BOUNDS 41, OPTIONS 42, COUNT 43, MOMENT 44).
- Theming codes start at 20. Navigation reserves 13 and 14, so a gap keeps both streams unambiguous when they merge.
- RANGE is exactly three words after its code word; COLUMNS is exactly two; MATERIAL is exactly two. A RANGE is 16 bytes, a COLUMNS is 12 bytes and a MATERIAL is 12 bytes.
- THEME carries exactly seven tones; its count word is 7. The encoder writes the count, and the host refuses any other count.
- Text is its UTF-8 byte length as one word, followed by those bytes.
- FETCH 38, CANCEL 39 and WAKE 40 follow REFRESH 37. FETCH is a generation word, two text fields, a header count word, then a name and a value text field per header, then a body text field. CANCEL and WAKE are one word after the code word. The instruction bound is 45; codes 41 to 44 are BOUNDS, OPTIONS, COUNT and MOMENT.
- Word counts after the code word: GESTURES 3, VALUE 2, HAPTIC 1, TRAITS 2, ANIMATE 2, REFRESH 2, BOUNDS 4, COUNT 2 and MOMENT 4. ACCESS_HINT and ACCESS_VALUE are a node and a text field. ALERT is a tag, a style, two text fields and a choice list; MENU is a node, a tag and a choice list.
- NAVIGATE is a route count, then per route an id word, a body node word and a text field, then a sheet flag word (1 or 0), followed by the sheet's id and body node when the flag is 1. A NAVIGATE with no sheet ends at the flag word.
- A choice list is a count word, then each choice's role word and a text field.
- `remove` writes the node, then the count of ids, then every id of the detached subtree, so the host can forget each one.
- Each function appends to the stream it is given and returns the extended stream; no function reads or reorders earlier bytes.

## Negative Logic

- No decisions: the encoder never chooses which instruction a commit needs, never compares two trees, and never allocates a node id.
- REFRESH is a node, a tag and a flag word, 16 bytes in all. The encoder writes the flag as 1 or 0; the host refuses any other value.
- No RESET. The view module no longer writes RESET, and this encoder does not spell it.
- No validation of node ids, indices or kinds. Refusing a bad instruction is the host's job, in [[iOS Host Adapter]].
- No window arithmetic. The first index and the total are passed through as given; [[Std Mobile View]] decides them.
- No I/O and no platform call.

## Dependencies and consumers

Depends on no other module. Consumers: [[Std Mobile View]], which calls these functions to build the stream of each mount and update, and [[Std Mobile Feedback]], which encodes alerts and haptics.

## Resolved Grill Log

- **Q:** Add a separate scroll instruction? **A:** CREATE identifies the viewport as a kind. APPEND, INSERT and REMOVE maintain its child.

- **Q:** Why a separate encoder module? **A:** The reconciler decides what changes; the encoder owns how an instruction is spelled, so neither grows into the other. _Rejected:_ one module for both.

- **Q:** Why codes 20 to 23 rather than the next free numbers? **A:** The navigation slice claims 13 and 14 in parallel; a gap keeps both streams unambiguous when they merge.

- **Q:** Why codes 24 and 25 for RANGE and COLUMNS? **A:** They continue after the theming codes without a gap, since no other slice claims them. A list's window and its grid shape are separate instructions, so a change to one writes only that instruction.
- **Q:** Why code 26 for MATERIAL? **A:** It continues the sequence with no gap. A material is one word of kind and one word of code, so a change of material writes one fixed-size instruction.

- **Q:** Why one NAVIGATE for the whole stack? **A:** A stack is one ordered list whose order and ids must agree, so the host checks it as a unit before any controller changes. Per-route instructions would expose a half-applied stack.

- **Q:** Why a separate instruction for each capability rather than one generic property word? **A:** Each capability has its own word count and its own validation. A generic property would make the host decode a second tag inside every instruction. _Rejected:_ one property instruction.

- **Q:** Why does the program choose the generation rather than the host? **A:** The program matches an answer to the request it sent. The host only tags answers with the number it was given, so a superseded answer can be recognized and dropped.

- **Q:** Why codes 41 to 44 rather than 36 to 39? **A:** Codes 36 to 40 are already NAVIGATE to WAKE on the iOS host. The value instructions take the next free codes, and both hosts share one numbering. _Rejected:_ reusing 36 to 39 for an Android-only meaning.
- **Q:** Why one kind per control rather than one control kind with a sub-tag? **A:** The host dispatches on kind through its table, so a kind per control keeps each setter and refusal in one table entry. _Rejected:_ a generic control kind with a second tag word, which would make the host decode a tag inside every create.
- **Q:** Why one signed word for a number? **A:** The program's Int32 reaches the stream as written, and the host reads the same word. _Rejected:_ a second sign word.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Theme]] · [[Std Mobile Control]] · [[Native Keyed Lists Delivery]] · [[Native iOS Scrolling Delivery]] · [[Native iOS Theming Delivery]] · [[Native iOS Recycling Delivery]] · [[Native iOS Materials Delivery]] · [[Native iOS Refresh Delivery]]
