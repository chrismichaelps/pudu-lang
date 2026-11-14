---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileView.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native]
aliases: [Uses Mobile View]
---

# Uses Mobile View

## Purpose and interface

Stdlib fixture for [[Std Mobile View]]. Its entry runs the checks below and answers the number of checks that held. The data spec asserts that count, stated there.

Checks:
- The build stream of the counter view, word by word: CREATE, TEXT, TAG and APPEND in order, ending with ROOT 0.
- A count change from 3 to 4 produces exactly one TEXT instruction, 20 bytes long: a 4-byte code, a 4-byte node, a 4-byte length and the 8 bytes of `Count: 4`. The count is one digit in this check so the length is fixed.
- Rows, fields, toggles and names: the build words of a tree with a row, a field, a toggle and a named control, in order.
- In-place changes of a tree of one shape: a changed field text, placeholder, toggle title, toggle state and accessible name each produce exactly one instruction, with its code word and bytes.
- A tag change, a child count change or a variant change resets the screen: each starts with RESET.
- Event decoding: `event` of kind 1 with tag 7 is `Tapped(7)`; kind 2 is `Stopped`; kind 3 with a text is `Changed(tag, text)`; kinds 4 and 5 are `Toggled(tag, true)` and `Toggled(tag, false)`; kind 9 reads as `Stopped`. `carriesText` is true only for kind 3.

## Invariants

- The fixture uses only the pure interface of [[Std Mobile View]]. It makes no foreign call.
- Each check compares an exact byte or word sequence, never a length alone.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator.
- A count with two digits is not checked here; its TEXT length differs by one byte per digit.
- Event text is supplied by the caller in this fixture; no host is asked for it.

## Dependencies and consumers

Depends on [[Std Mobile View]]. Its counter view matches [[Native Counter Example]]; its field and toggle checks mirror [[Native Form Example]].

## Resolved Grill Log

- **Q:** Check the stream as bytes or as a summary? **A:** As words and bytes, because the host decodes the words; a summary such as "contains a TEXT" would pass a wrong length. _Rejected:_ golden snapshots, which would hide a semantic change behind an update.

## Referenced by

[[Std Mobile View]] · [[Native First Light Delivery]] · [[Native Controls Delivery]]
