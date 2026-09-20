---
type: handoff
status: REVIEW_READY
tags: [handoff, stdlib, html, performance, testing]
---

# HTML Renderer Scheduling and Fragment Overhead

## Objective

Resolve issue #256 by replacing eager sibling scheduling and repeated pending-stack slices with an
iterative cursor-frame traversal, while preserving exact HTML bytes, public chunk boundaries,
escaping, handler blocking, and both document-prefix spellings.

## Ownership and role transitions

1. **Language Architect:** [[Std Html]] and [[Std Html Build]] fix the compatibility boundary:
   `renderChunks` grouping and public APIs do not change in this slice.
2. **Runtime Engineer:** `packages/pudu/v0.1/lib/Std/Html.pudu` and
   `packages/pudu/v0.1/lib/Std/Html/Build.pudu` own cursor scheduling and prefix delegation.
3. **Test Engineer:** `test-fixtures/stdlib/UsesHtml.pudu`,
   `test-fixtures/stdlib/UsesHtmlBuild.pudu`, and
   `test/Pudu/Compiler/Program/Eval/ServiceSpec.hs` own exact output, refusal, deep/wide, and
   regression evidence.
4. **Forensic Guardian:** reconcile both module mirrors, backlinks, the changelog, and this handoff
   after focused and full gates pass.

The owned files are exclusive to this issue branch. Preserve unrelated work and do not broaden this
slice into SSR plan compaction, byte assembly, streaming, compiler primitives, or public builder
safety changes.

## Baseline and decided contract

The current evaluator stores arrays as persistent sequences: `push` and `pop` are constant time,
indexed reads and updates are logarithmic, and `slice` is logarithmic. The renderer nevertheless
slices its pending stack once per step and pushes every child in reverse order.

A focused depth-1,600, width-1,200, 40-attribute probe reported 358,532 evaluator steps,
2,336,078,616 host bytes allocated, 3,868,920 bytes maximum residency, and 0.855 seconds elapsed on
the current no-optimization build. Treat these as same-machine comparison evidence only.

The replacement keeps the active child collection and index in local cursor state. It suspends one
parent continuation only when descending into non-empty children and restores it with `pop`. Public
fragment grouping stays unchanged. `Std.Html.document` seeds its traversal; `Std.Html.Build.document`
prepends its compact prefix to the chunks before their one final join.

## Exact next action

Request independent implementation and Forensic Guardian parity review. If no P0/P1 findings remain,
commit with the issue reference, push the branch, and open the issue-closing pull request to `dev`.

## Completion evidence

- Focused optimized fixture results: `UsesHtml = 66`, `UsesHtmlBuild = 97`, and
  `UsesDeepRenderers = 15`.
- The before/after probe records reductions of 12.7% in evaluator steps, 14.6% in allocated bytes,
  12.1% in maximum residency, and 24.7% in elapsed time on the same local no-optimization build.
- `bash test/gates.sh` passes the warning-free optimized build, full optimized suite, formatter,
  diagnostic-code, release-plan, API coverage, residency, scaffold, lint, LSP session/robustness, and
  documentation-site gates.
- Source, both module mirrors, backlinks, the standard-library MOC, changelog, fixtures, and this
  handoff agree. Public chunk grouping and APIs are unchanged.

## Referenced by

[[handoffs/_MOC]] · [[Std Html]] · [[Std Html Build]] · [[architecture/STDLIB]]
