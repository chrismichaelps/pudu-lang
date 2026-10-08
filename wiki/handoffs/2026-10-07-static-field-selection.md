---
type: handoff
status: ACTIVE
issue: 457
tags: [derive, semantics, runtime]
---
# Static Field Selection Repair

Language Architect resolves complete static owner selection in the residualizer, call checker,
expression checker, pure implementation matcher and post-check owner lowering. Semantic Engineer owns
only those four selection modules, [[Compiler Literals]], [[Compiler Pipeline]], [[Name Resolution]], [[Eval Install]], [[Derive Library Spec]], [[Static Collect Fixture]] and its imported
[[Static Collect Bind Fixture]], and [[Static Collect Local Fixture]], and [[Derive Expand Expected]], with their mirrors and navigation. Work is sequential from fresh
development on `feature/457-static-field-selection`; preserve unrelated work.

The reported imported strategy reproduces E7001 at the nested parameter call under collect.
Explicit selection makes the literal implementation return 1. A positional argument substitution
would regress reordered and nested implementation heads; retain the complete owner and use the
existing structural matcher. Conditional obligations and ordinary method inference remain active.
All mirrors and resolved Grill Logs precede source edits. Independent semantic and parity review
remain pending. The application goal and #458 continue after this repair.

The parser and resolver retain their existing grammar. Generated complete owner annotations lower
to ordinary explicit method applications in both executable and expanded output. Authored nodes
and literal syntax remain unchanged. Generated owner annotations resolve in the type namespace. Constant folding receives their
settled ordinary selections; authored index syntax stays unchanged. A local expansion is recompiled and run in both evaluators.

Acceptance: original reproduction, nested and reordered heads, generic target, explicit and
inferred method parameters, ordered failure results, unchanged existing refusals, both evaluators,
packed execution, strict build, full compatibility, formatting, lint and dependency checks.

Runtime Engineer additionally owns the initialization module-scope marker in [[Eval Install]], resolved
before that source edit. All other evaluation and linkage behavior stays within existing contracts.

Validation: strict optimized build and full compatibility suite pass. The original reproduction
prints the literal implementation's 1. Imported and local fixtures pass cached and source-only
packaged execution in both evaluators. Formatting, lint, 14 graph checks, the 215-module framework
graph and 283-module source graph pass with no dependency findings. The pre-repair compiler fails
the imported fixture with E7001. The three optional text decoder snapshot changes were inspected.
The final added-link audit resolves every vault link; private inputs remain outside the diff.

Exact next action: repair #458 on a fresh branch from integrated development.

## Referenced by

[[handoffs/_MOC]] · [[Derive Library Spec]] · [[Derive Record Residualizer]]

## Development integration (2026-10-08)

Release Owner performs the maintainer-requested merges in creation order. Earlier repairs
#461, #463, #464 and #465 are integrated. This final overlap preserves all changelog and
navigation entries; implementation sources merge without conflict. No independent review is inferred.
The combined warning-strict optimized build, full compatibility suite, complete bundle deployment
gate and fourteen graph tests pass. Cached and source-only execution preserve caller environment;
all added vault links resolve. The framework graph has zero findings and source imports have no cycles.
The broader application audit and derive index repair remain active.
