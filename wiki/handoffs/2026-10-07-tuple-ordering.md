---
type: handoff
status: VALIDATED_FOR_MERGE
issue: 442
tags: [runtime, tuple, ordering]
---
# Tuple Ordering Delivery

Language Architect resolves the existing tuple-key order as the expression-ordering contract.
Runtime Engineer owns [[Eval Operator]], [[Eval Arithmetic Tests]], [[Eval Test Coordinator]] and
[[Uses Tuple Ordering]]. Work is sequential. No public signature, grammar or tuple equality change is required.
The maintainer subsequently requested merging completed requests in creation order; independent
semantic and vault-parity review has not occurred.

The issue reproduction checks without diagnostics, then fails at runtime with E7001. Use the
existing lexicographic value order for four relations, guard both complete tuples, preserve all
other dispatch paths and test constants, sorting, failures and operand effects.

The reported reproduction now checks and exits zero. Direct and packed fixture execution,
formatting, lint and focused checks pass. Temporarily bypassing comparability makes the exact
E7001 assertion fail. The runtime dependency graph has 283 modules and no cycles; the application
graph has 214 modules and no findings. The complete warning-strict optimized suite passes.
The reported reproduction and broader fixture pass packed execution; the fixture also passes
confined execution. Independent review has not occurred.

The combined framework checkout preserves both tuple and resource-disposal test registrations.
Its application graph contains 215 modules and 96 framework dependencies with no findings.

Exact next action: verify the final ordered development merge, then continue issue #456.

## Referenced by

[[handoffs/_MOC]] · [[Eval Operator]]
