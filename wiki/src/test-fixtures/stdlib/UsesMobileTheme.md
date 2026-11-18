---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileTheme.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native]
aliases: [Uses Mobile Theme]
---

# Uses Mobile Theme

## Purpose and interface

Stdlib fixture for [[Std Mobile Theme]] and the theme additions of [[Std Mobile View]]. Its entry drives `stream`, `restyled`, `mount` and `update` through the checks below and answers the number of checks that held: 12. The data spec asserts that count.

Checks:
1. The platform theme stream is THEME with seven zero tones, then APPEARANCE 0, 100 bytes in total.
2. A fixed ink pair packs its channels little-endian as R, G, B, A.
3. A dark appearance writes `[21, 2]`.
4. `restyled` with an identical theme writes nothing.
5. `restyled` with a changed theme equals `stream` of the new theme.
6. A styled label mounts CREATE, TEXT, then STYLE with body (code 4) on the label's id, then ROOT.
7. A painted button writes COLOR danger (code 5) on its id.
8. Changing the style of a mounted styled label writes exactly one 12-byte STYLE.
9. An unchanged styled tree writes nothing.
10. Changing a painted role writes exactly one COLOR.
11. Removing the `Styled` wrapper replaces the node: a new CREATE, ROOT, then REMOVE of the old id.
12. Nested `Named`, `Styled` and `Painted` wrappers write COLOR, STYLE and NAME on the same node id 0.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone.
- The fixture makes no foreign call. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator. The painted colors are checked by [[iOS Host Theme]] through the self-test of [[Native Themed Example]], not here.
- Checks do not depend on the order of the platform's own default colors.

## Dependencies and consumers

Depends on [[Std Mobile Theme]], [[Std Mobile View]] and [[Std Mobile Stream]]. Its styled and painted checks mirror the wrappers that [[Native Themed Example]] uses.

## Resolved Grill Log

- **Q:** Check bytes or summaries? **A:** Exact words, as for [[Uses Mobile View]]. A summary such as "contains a STYLE" would pass a wrong code or a wrong node id.

## Referenced by

[[Std Mobile Theme]] · [[Std Mobile View]] · [[Native iOS Theming Delivery]]
