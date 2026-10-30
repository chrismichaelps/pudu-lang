---
type: handoff
status: ACTIVE
aliases: [Binary Codec Delivery]
tags: [handoff, runtime, serialization]
---
# Binary Codec Delivery

Issue #739 runtime partition owns Eval.Binary, native codec properties, package/test registration
and matching mirrors/navigation. Architect resolved the wire contract and exact-bit oracle before
implementation; Runtime Engineer implements; Tooling/Release validates. Preserve ongoing library,
builtin-wiring and benchmark work in this checkout. No delegated agents. The current delivery instruction authorizes tested engine merges to dev.

The native property families pass 200 generated canonical round trips, 200 strict-truncation
cases, and fixed malformed/nesting/golden boundaries. The optimized warning-free build passes.
The clean full repository gate passed on the working continuation; the native properties also
passed after adding deliberately reversed field order. Hosted checks must validate this isolated
partition without the pending facade/wiring edits. The project owner waived independent review for this engine delivery loop on 2026-10-30;
merge follows successful required checks.

This partition does not complete #739: the public Encode/Decode derives, runtime builtin wiring,
evolution fixture, serialization benchmark and facade delivery remain required.

Native delivery: [PR #741](https://github.com/chrismichaelps/pudu-lang/pull/741), draft to dev,
commit b728aa61. Local full gates pass; hosted checks and independent reviews remain pending.

Integration update: merge current dev after the native partition, preserving both changelog histories.
The previous head passed all hosted checks; rerun the clean full gate on the integrated head.
Independent review is waived for this loop by the project owner.

Exact next action: validate the integrated native partition before delivering the dependent facade.

## Referenced by

[[handoffs/_MOC]] · [[Eval Binary]] · [[Binary Codec Properties]]

Writer validation update: public facade reproduction proved successful writes could exceed the
reader nesting limit or duplicate fields. The new native boundary test failed before repair.
The writer now shares the reader depth limit and validates per-record field-name uniqueness;
sibling records still share names. Revalidate native properties and the full gate before merging.
The project owner waived independent review for this engine delivery loop on 2026-10-30.

The writer-corrected a24e0701 passed every clean local gate. PR #744 merged into dev as a6f85d584;
merge that prerequisite while preserving both navigation/changelog entries. Code changes are the
already-tested explicit-provider repair. Refresh required checks on the combined head before merge.
