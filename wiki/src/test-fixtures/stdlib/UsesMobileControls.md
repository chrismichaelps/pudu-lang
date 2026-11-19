---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileControls.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, controls]
aliases: [Uses Mobile Controls]
---

# Uses Mobile Controls

## Purpose and interface

Stdlib fixture for the value controls of [[Std Mobile Control]], their instructions in [[Std Mobile Stream]], and their events in [[Std Mobile Events]]. Its entry `main` builds and changes each control through `built` and `changed`, decodes the three value events, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is 25.

Checks:
1. A slider with value 40 on bounds 0 to 100 by 10 builds as CREATE 12, TAG, BOUNDS 41, VALUE 29 with the value 40, then ROOT, exact words.
2. Inverted bounds (high below low) normalize to low: the BOUNDS words carry high equal to low.
3. A step of 0 reads as 1: the BOUNDS words carry step 1.
4. Negative bounds are written as two's complement words.
5. A value above high is clamped to high, and a value between steps is snapped down to the step grid.
6. An update whose snapped value is unchanged writes nothing.
7. An update that moves the snapped value writes one VALUE and nothing else.
8. New bounds write one BOUNDS, and the value is resent after it.
9. A changed tag alone replaces the node: the old subtree is removed and a new one is built.
10. A slider changed to a stepper replaces the node.
11. Segments build OPTIONS with the label count and each label length-prefixed, then TAG, then VALUE.
12. A selected index past the last label is clamped to the last label.
13. An empty wheel sends no OPTIONS and no VALUE.
14. Emptying a segments list replaces the control rather than updating it.
15. A date moment with positive seconds writes mode, high word 0 and the low word.
16. A date moment above 2^32 writes a high word of 1.
17. A date moment of -1 writes an all-ones high word and an all-ones low word.
18. A page indicator past its count is clamped to the last page, with COUNT before VALUE.
19. A color well writes its RGBA value as the VALUE word.
20. A symbol writes TEXT only, with no TAG.
21. A search field writes HINT, then TEXT.
22. An unchanged text area writes nothing.
23. Event kind 21 with a negative detail word decodes to `Valued` with the signed value.
24. Event kind 22 decodes to `Colored` with the RGBA detail word.
25. Event kind 23 with two words decodes to `Dated` with the combined seconds; a different word count decodes to `Stopped`.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone.
- The fixture makes no foreign call. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator. The host's refusals are checked by the simulator run of [[Native Controls Example]], not here.
- No refusal is checked here. Inverted slider bounds, empty segment labels and a value on a label are refused by the host.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile View]], [[Std Mobile Stream]] and [[Std Mobile Events]]. Its checks mirror the contract that [[Native Controls Example]] and [[pudu-ios-values]] rely on.

## Resolved Grill Log

- **Q:** Check bytes or summaries? **A:** Exact words, as for [[Uses Mobile Refresh]]. A summary such as "contains a VALUE" would pass a wrong value or a wrong node id.
- **Q:** Why check the normalization cases separately from the builds? **A:** A normalization bug changes the words without changing the shape, so only an exact check of the clamped and snapped value catches it.

## Referenced by

[[Std Mobile Control]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Native Value Controls Delivery]]
