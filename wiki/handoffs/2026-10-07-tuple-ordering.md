---
type: handoff
status: AWAITING_REVIEW
issue: 442
tags: [runtime, tuple, ordering]
---
# Tuple Ordering Delivery

Language Architect resolves the existing tuple-key order as the expression-ordering contract.
Runtime Engineer owns [[Eval Operator]], [[Eval Arithmetic Tests]], [[Eval Test Coordinator]] and
[[Uses Tuple Ordering]]. Work is sequential. Independent semantic and vault-parity review precedes
integration; no public signature, grammar or tuple equality change is required.

The issue reproduction checks without diagnostics, then fails at runtime with E7001. Use the
existing lexicographic value order for four relations, guard both complete tuples, preserve all
other dispatch paths and test constants, sorting, failures and operand effects.

The reported reproduction now checks and exits zero. Direct and packed fixture execution,
formatting, lint and focused checks pass. Temporarily bypassing comparability makes the exact
E7001 assertion fail. The runtime dependency graph has 283 modules and no cycles; the application
graph has 214 modules and no findings. The complete warning-strict optimized suite passes.
The reported reproduction and broader fixture pass packed execution; the fixture also passes
confined execution. Independent review has not occurred.

Exact next action: obtain independent semantic and vault-parity review of the focused repair.

## Referenced by

[[handoffs/_MOC]] · [[Eval Operator]]
