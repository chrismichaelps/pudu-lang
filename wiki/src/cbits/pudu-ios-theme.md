---
type: module
path: "@root/cbits/pudu_ios_theme.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Theme]
---

# iOS Host Theme

## Purpose and interface

Private UIKit theming implementation included once by [[iOS Host Adapter]]. The compiler stages it alongside the host translation unit and the layout header [[iOS Host Layout]]. It owns the role table, the appearance override, the text style mapping and the paint of colored controls. Theming is its own responsibility, as layout is, which keeps the host file within its line budget.

The header handles four instructions of [[Std Mobile Stream]]: THEME (20), APPEARANCE (21), STYLE (22) and COLOR (23).

## Behavior

- The role table holds seven colors. The defaults are the platform's own semantic colors: Surface the system background, Ink the label color, Accent the system blue, OnAccent white, Muted the secondary label color, Danger the system red and Separator the separator color.
- A `Fixed` tone becomes a dynamic color. Its provider answers the dark color under the dark user-interface style and the light color otherwise.
- THEME requires a count of 7. Any other count is a stream defect and aborts. It replaces the role table, sets the root surface background to Surface, sets the window tint to Accent, and then repaints every shown node.
- Repainting: a node with an explicit COLOR keeps its role. Labels, field text and toggle titles otherwise take Ink. Buttons follow the tint.
- APPEARANCE sets the window's user-interface style override: unspecified for 0, light for 1, dark for 2. Any other code is a defect.
- STYLE maps codes 1 to 8 to the platform text styles: large title, title 1, headline, body, callout, subheadline, footnote and caption 1. It sets the font from the preferred font for that style and enables automatic adjustment to the content size category, so a Dynamic Type change needs no Pudu work. Code 0 or any code above 8 is a defect.
- COLOR records the node's role and paints it at once. A role of 7 or more is a defect.
- A kind without text (column, row, scroll) refuses STYLE and COLOR with a defect.
- Self-test `PUDU_UI_THEME_TEST`: on the first label it prints `PUDU_THEME ink light #RRGGBBAA dark #RRGGBBAA`, the text color of that label resolved under the light and the dark trait collections. It prints `PUDU_THEME appearance dark` when the window override is dark. It prints `PUDU_THEME type grows` when the font of its style at the accessibility extra-large content size is larger than at the default size. Then it asks the program to stop.

## Invariants

- Every platform call of this header runs on the thread that runs the program, as every call of [[iOS Host Adapter]] does.
- The role table has exactly seven entries, indexed by the role code.
- A repaint reads only the stored role and style of each node. It never reads a Pudu value.

## Negative Logic

- No application logic. A role names a slot in the table; no control chooses its own color.
- No per-node color instruction for every themed control. A theme repaints the shown nodes.
- No color is resolved in Pudu. The dynamic provider answers the appearance at draw time.
- No silent no-op. A STYLE on a group is refused, so a program error stops the process with the stream defect message.
- No retry of a malformed theme instruction.

## Dependencies and consumers

Depends on UIKit. Included by [[iOS Host Adapter]]. Its instructions are encoded by [[Std Mobile Theme]] and [[Std Mobile View]] through [[Std Mobile Stream]]. Staged by [[Backend Toolchain App]] and listed in [[Native Toolchain Host Sources]].

## Resolved Grill Log

- **Q:** Why a separate header? **A:** The host file is near the 500-line budget; theming is its own responsibility, as layout is.
- **Q:** Repaint on every THEME? **A:** Yes; themes change rarely and repainting the shown nodes is bounded by the screen. _Rejected:_ per-node color instructions for every themed control.
- **Q:** Why refuse STYLE on groups? **A:** A silent no-op would hide a program error; refusals abort with the stream defect message like every other malformed instruction.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host Layout]] · [[Std Mobile Theme]] · [[Native iOS Theming Delivery]]
