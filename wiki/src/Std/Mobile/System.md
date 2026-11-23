---
type: module
path: "@root/lib/Std/Mobile/System.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui, system]
aliases: [Std Mobile System]
---

# Std Mobile System

## Purpose and interface

Pure description of the system requests a program makes of the platform: open a URL, share text, copy and paste text, and set the status bar. Each request is a commit, like the alert of [[Std Mobile Feedback]]. The module builds the instructions and the words that carry them; it performs no I/O. The answers come back as events that [[Std Mobile View]] decodes: `Opened`, `Shared` and `Pasted`. Words are spelled by [[Std Mobile Stream]], and the reports are decoded by [[Std Mobile Events]].

Exports:
- `type Bar = Automatic | LightText | DarkText`: the status bar style. Codes 0, 1 and 2 in that order, read by `barCode`.
- `barCode(bar: Bar) -> UInt32`: the code of a status bar style.
- `open(tag: UInt32, url: Str) -> Bytes`: a commit that asks the platform to open a URL. The answer is `Opened(tag, Bool)`.
- `share(tag: UInt32, text: Str) -> Bytes`: a commit that shows the system share sheet with the text. The answer is `Shared(tag, Bool)`.
- `copy(text: Str) -> Bytes`: a commit that places the text on the system clipboard. It reports nothing.
- `paste(tag: UInt32) -> Bytes`: a commit that reads the system clipboard. The answer is `Pasted(tag, text)`.
- `statusBar(style: Bar, hidden: Bool) -> Bytes`: a commit that sets the status bar style and whether it is hidden. It reports nothing.

## Behavior

- `open` names the tag its answer reports and the URL text. A URL the platform cannot read is answered `Opened(tag, false)` at once, without a request to the platform's opener.
- `share` answers once, when the share sheet closes. `Shared(tag, true)` means the person shared the text; `false` means the sheet was dismissed.
- `paste` answers with the clipboard's text. When the clipboard holds no text the answer is `Pasted(tag, "")`.
- `statusBar` is a standing setting. It holds until a later commit sets it again.

## Keyboard and back (#990)

- `dismissKeyboard() -> Bytes`: KEYBOARD 77 with no words. It reports nothing.
- `handleBack(on: Bool) -> Bytes`: BACK 78. With `on` true, the platform's back gesture or button answers BACKED instead of its own action. With `on` false, the gesture returns to the platform. It reports nothing. The answer arrives as `Backed` in [[Std Mobile Events]].
- Both are standing commits, like `statusBar`. Neither writes a node.

## Invariants

- Every request that reports an answer carries a tag, and the answer carries the same tag. A program matches an answer to its request by tag.
- Status bar codes come from the constant table of `Bar`. No code is chosen by an if-ladder.
- No request writes a node into the view tree. `copy` and `statusBar` report nothing, and `open`, `share` and `paste` report exactly one answer each.

## Negative Logic

- No view. A system request is not a node: it has no place in the tree, no reconciliation and no persistent state in the view. Keeping it out of the tree means a dismissed sheet or an opened URL cannot linger as a node the program must remove.
- No stored answer. The module never records what the platform answered; the program receives it as an event.
- No platform call. The effects are made by the host in [[iOS Host System]] and [[PuduSystem]].
- No read of the clipboard by the program on its own. Reading happens only when the program asks with `paste`.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the OPEN, SHARE, COPY, PASTE and STATUS instructions. Consumers: [[Std Mobile View]], which decodes the `Opened`, `Shared` and `Pasted` events; the host [[iOS Host System]] and the Android host [[PuduSystem]]; the example [[Services Example]]; and the fixture [[Uses Mobile System]].

## Resolved Grill Log

- **Q:** Why commits rather than view nodes? **A:** A system request is a one-shot effect with a reported outcome, as an alert is. A node would stay in the tree after the request finished, and a status bar setting has no place in a tree at all. _Rejected:_ a view node per request, which would need the program to remove each one after its answer.
- **Q:** Why does Android report that a share was shown rather than that it was shared? **A:** The platform's chooser does not report which target the person picked or whether they finished, so the host cannot see the outcome. Android reports `Shared(tag, true)` once the chooser opens. iOS reports the completion of its share controller, which does carry the outcome. A program that needs the exact result must not rely on the Android answer.
- **Q:** Why does an unreadable URL answer false at once? **A:** The platform's opener would answer asynchronously with the same refusal. Answering at once keeps the program's pending request from waiting on a call that cannot succeed.
- **Q:** Why is the status bar a commit and not part of a screen? **A:** The status bar belongs to the scene, not to any one screen. A setting carried by a screen would reset whenever the screen changed.

## Referenced by
 · [[Viewer Example]]
[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Std Mobile Feedback]] · [[NATIVE-MOBILE]]
