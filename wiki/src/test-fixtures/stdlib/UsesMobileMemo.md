---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileMemo.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, performance]
aliases: [Uses Mobile Memo]
---

# Uses Mobile Memo

## Purpose and interface

Stdlib fixture for the memoized subtrees of [[Std Mobile View]] (`View.Memo`, `View.measured`) and their
keyed constructor [[Std Mobile Memo]]. Its entry `main` mounts a list of 100 rows, each a row of four nodes
built with `Memo.lazy("row", Memo.Render(row), item)`, where `row` is a module-level function and
`Memo.Render` is the `@static_function` constructor of [[Std Mobile Memo]]. It answers the number of checks that held. The data spec
`test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is 5.

Checks:
1. Unchanged rows: `measured` compares 101 nodes (the keyed list and the 100 memos), renders nothing,
   reports 100 reused memos, and writes an empty stream.
2. One changed row: `rendered` is 1, `reused` is 99, and `compared` is 105, which counts the changed memo's
   own four nodes as well as the 101 above.
3. The stream of that change is one 19-byte TEXT for node 22, whose first words are `[2, 22, 7]`.
4. The same rows without memos: `measured` compares 401 nodes, every node of every row, and renders nothing.
5. Equal keys at different sites are different memos: `Memo.lazy("question", ...)` replaced by
   `Memo.lazy("answer", ...)` with the same key renders once, reuses nothing, and writes a stream whose
   first words are `[2, 0, 8]`.

## Invariants

- Each check compares an exact counter or an exact word sequence, never a count of rows alone.
- The fixture makes no foreign call. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No simulator is started. The fixture checks the stream and the counters, not the frame budget;
  frame timing needs physical traces, as [[Pudu Native iOS UI]] requires.
- The fixture does not check the checker rule of [[Native Render Skipping]]. A render that captures
  state is refused by [[Type Check Static]] with E3103; its two refusal forms are [[Memo Render Lambda]]
  and [[Memo Render Local]].

## Dependencies and consumers

Depends on [[Std Mobile View]] and [[Std Mobile Memo]]. Its checks state the cost contract of
[[Native Render Skipping]] as exact numbers.

## Resolved Grill Log

- **Q:** Check counters or only the screen? **A:** Both. The screen proves the output is right; the
  counters prove the skipping happened. A screen check alone would pass a build that renders everything.
- **Q:** Why check that a changed key renders once? **A:** A render that runs twice per change would still
  show the right screen; only an exact count of one catches it.

## Referenced by

[[Std Mobile View]] · [[Std Mobile Memo]] · [[Native Render Skipping]] · [[Pudu Compiler Program Eval Data Spec]]
