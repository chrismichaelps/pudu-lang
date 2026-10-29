---
type: handoff
status: IN_REVIEW
issue: 662
aliases: [Flat Expression List Delivery]
tags: [handoff, delivery, parser]
---
# Flat Expression List Delivery

Fresh feature/662-flat-expression-lists starts from fetched development b230a5d6. The pending
full-range root repair (#661) is parked unchanged on its own branch until this parser repair lands.

Role transitions: Architect → Frontend Engineer → Test Engineer → independent Forensic Guardian.
Frontend Engineer owns Parser/Expression/Aggregate.hs and Postfix.hs; Test Engineer owns
RecoverySpec and the ParserExpressionSpec registration; Architect owns mirrors and navigation.

Observed defect: array, Set and call-argument tails held a recursion-budget frame across the
recursive sibling call, so every comma consumed one nesting frame and a flat list of roughly 520
items reported E1099. Repair: one shared `parseSiblingItems` loop in Aggregate reads siblings
iteratively; each item's expression parse charges and restores its own depth. Progress checks and
the exhausted-budget latch still stop the loop. The 512-depth limit and Parser.State are unchanged.

Evidence: the new flat-list property fails on the pre-repair parser (wide array reports E1099)
and passes after it. All 127 parser property labels pass in a focused sweep. The 217 shipped
library modules and the examples check without parse diagnostics. Former E1099 expectations for
520-wide calls and Sets, and the 1022 offset assertion, encoded the defect and are corrected.
Deep arrays, Sets, calls and depth-after-width each still report exactly one E1099.

Exact next action: restore the parked full-range root work from its stash onto
feature/661-full-range-sqrt and finish its golden checks, then continue Ark Math/Core.

## Referenced by

[[handoffs/_MOC]] · [[Expression Recovery Spec]] · [[Expression Parser Spec]]
