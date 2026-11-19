---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileRefresh.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, refresh]
aliases: [Uses Mobile Refresh]
---

# Uses Mobile Refresh

## Purpose and interface

Stdlib fixture for the refresh additions of [[Std Mobile View]] and their instruction in [[Std Mobile Stream]], and for the insets event of [[Std Mobile Events]] and [[Std Mobile Scene]]. Its entry `main` drives `mount`, `update`, `event`, `eventWithWords` and `insets` through the checks below and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is 9.

Checks:
1. A scroll wrapped in `Refreshing` mounts as a CREATE of kind 7 followed by an APPEND of its label, 73 bytes in all.
2. The mount writes a REFRESH naming the scroll with tag 4 and flag 0, and then a ROOT that shows the scroll.
3. A changed refreshing flag alone is one 16-byte REFRESH with the same node, tag 4 and flag 1.
4. An unchanged `Refreshing` view writes nothing.
5. A changed tag alone is one 16-byte REFRESH with the same node, tag 5 and flag 0.
6. A list wrapped in `Refreshing` mounts with a CREATE of kind 8, and its REFRESH with tag 7 and flag 1 comes before the ROOT.
7. Event kind 16 with tag 4 decodes to `Refreshed(4)`, and is not a word-carrying event.
8. Event kind 17 with four words decodes to `SafeArea` whose top, left, bottom and right insets are those words, read as signed values.
9. Event kind 17 with two words decodes to `Stopped`, and `insets` returns `None` for a single word.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone.
- The fixture makes no foreign call. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator. The pull itself and the indicator are checked by the simulator run of [[Native Refresh Example]], not here.
- No refusal is checked here. A REFRESH on a node that does not scroll is refused by the host, which the simulator run checks.

## Dependencies and consumers

Depends on [[Std Mobile View]], [[Std Mobile Stream]], [[Std Mobile Events]] and [[Std Mobile Scene]]. Its checks mirror the contract that [[Native Refresh Example]] and [[pudu_ios_refresh.h]] rely on.

## Resolved Grill Log

- **Q:** Check bytes or summaries? **A:** Exact words, as for [[Uses Mobile View]]. A summary such as "contains a REFRESH" would pass a wrong node id or a wrong flag.
- **Q:** Why check the flag and the tag separately? **A:** A change to only one of them must write exactly its own REFRESH; a combined check would hide a commit that rewrote both.

## Referenced by

[[Std Mobile View]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Native iOS Refresh Delivery]]
