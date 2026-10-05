---
type: module
path: "@root/bench/layers/view.mjs"
fidelity: Active
tags: [module, tooling, visualization, performance]
aliases: [Dependency Layer View]
---

# Dependency Layer View

## Purpose and interface

Render a self-contained HTML document from [[Dependency Layer Model]] JSON.
Treemap area represents the selected exclusive metric: allocated bytes, sampled
CPU milliseconds, entries, module count or dependency coupling. Controls filter
layers and module names. A sorted table is the readable/keyboard alternative.

## Algorithm and invariants

Partition weighted rectangles recursively by balanced summed weight, grouping
layers first and module boxes inside each layer. Zero/unknown metrics do not get
invented area; filtered module tables retain them. Layer totals count each module
once. Selecting a module shows source location, exclusive measures, highest cost
centres, imports/importers and navigable neighbors. Dependencies/importers have
different highlights. SCC cycle summaries list actual members. Display graph
and profile provenance, coverage/unmatched totals and measurement limitations.

Embed JSON with less-than characters escaped and populate user text with DOM
textContent. No interpolation into executable JavaScript, untrusted innerHTML,
external assets, eval or network calls. Disabled metrics explicitly lack data.
Native buttons/labels, visible focus and a table support keyboard use. Responsive
layout retains a fixed-height map and scrollable details/table on small screens.

## Resolved Grill Log

- **Q:** Draw all modules equally under an allocation label? **A:** No; expose
  a separate module-count metric, and never synthesize a measured cost.
- **Q:** Claim graph neighbors caused a hotspot? **A:** No; costs are exclusive
  instrumented observations. Source dependencies only provide investigation context.
- **Q:** Omit costs outside this source root? **A:** No; show their totals and
  owners separately so the selected source graph is not mistaken for total RSS.

## Referenced by

[[Dependency Layer Report]] · [[Dependency Layer Model]] · [[Dependency Layer Tests]]
