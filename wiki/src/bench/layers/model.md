---
type: module
path: "@root/bench/layers/model.mjs"
fidelity: Active
tags: [module, tooling, performance]
aliases: [Dependency Layer Model]
---

# Dependency Layer Model

## Purpose and interface

Pure model functions extract declared module/import identities, build the source
graph and parse GHC textual .prof or ticky tables. Return JSON-safe nodes,
components, layers, cost centres, totals and unmatched profile module rows.
Consumers are [[Dependency Layer Report]], [[Dependency Layer View]] and
[[Dependency Layer Tests]]. No filesystem, compiler or browser dependencies.

## Algorithm and invariants

Mask nested block comments, line comments, strings and character literals before
anchored declaration/import scanning. Accept safe/qualified/package/multiline
ordinary imports; SOURCE imports remain structural edges. This is a bounded
source scanner, not a preprocessor or a replacement for GHC's parser; imports
across CPP branches are conservative. Missing module headers fail explicitly.
Deduplicate edges and reject duplicate identities. Keep external imports separate.
Iterative depth-first SCC discovery avoids recursion limits. Condense SCCs into
a DAG; layer zero has no internal dependencies and callers have one plus their
largest dependency layer. Cycles are non-singleton SCCs or singleton self edges.
Compute importers and layer aggregates without duplicating node costs.

GHC cost-centre profiles prefer complete call-tree individual time/allocation
columns, never inherited columns or the duplicate flat summary. Convert reported
percentages using total CPU seconds and allocated bytes; retain rounding and
flat-summary truncation caveats. Accept optional SRC columns. Ticky rows use
Entries and Alloc, excluding Alloc'd; resolve global qualified closure owners or
local closure module annotations. Unattributed rows remain unmatched. Reject
unrecognized tables, malformed numeric rows, unsafe integers and non-finite values.
Uninstrumented costs are unknown. Sum exclusive costs only within each module.

## Resolved Grill Log

- **Q:** Traverse recursively? **A:** No; explicit stacks and condensation
  scheduling support long dependency chains without JavaScript stack overflow.
- **Q:** Treat namespaces or profile call paths as import edges? **A:** No;
  only actual source imports establish graph dependencies and source SCCs.
- **Q:** Sum inherited .prof columns or ticky Alloc'd? **A:** No; both would
  mix allocation ownership and double-count costs. Use individual .prof columns
  and allocations by a ticky closure, with clear instrumentation caveats.
- **Q:** Lose profile owners outside the root? **A:** No; expose unmatched
  modules and their exclusive totals in the report and companion JSON.

## Referenced by

[[Dependency Layer Report]] · [[Dependency Layer View]] · [[Dependency Layer Tests]]
