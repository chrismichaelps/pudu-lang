---
type: handoff
status: ACTIVE
aliases: [Bound Provider Delivery]
tags: [handoff, compiler, runtime]
---
# Bound Provider Delivery

Issue #743 starts from fetched dev e6377da5 on feature/743-bound-provider-evidence.
Architect resolves evidence ownership; Semantic Engineer owns checker provider products and
executable projection; Runtime Engineer owns exact selected-key lookup and installation;
Tooling/Release owns focused and full validation. Preserve other engine work. No delegated agents.
The project owner waived independent review for this engine delivery loop on 2026-10-30.
Merge follows successful required checks.

The generic body checks against TextWire but executes IntWire because receiver dispatch erases
the selected trait. Canonical provider facts become private resolved member symbols in the
executable tree only, using the existing checked-product cache. Implementation trait paths are
canonicalized in the same projection; ordinary explicit qualifier aliases remain installed.
No public grammar or type-argument witness extension is needed. This restores the existing
trait selection contract; imported admission #734 and conditional implementation #735 stay separate.

Scope owns Type.Env, Type.Check, Type, Type.Check.Method, Compiler, Compiler.Literals,
Eval.Env, Eval.Install, Repl.Session inspection, their mirrors, regression coverage and navigation.

The cache-disabled original regression printed 7 before the repair. The optimized warning-free
incremental build passes, and the focused gate passes Int, Str and Box receivers, both declaration
orders, two bound parameters sharing a runtime type, direct/alias/retained/default calls, both
evaluators and disabled/cold/warm caches. Warm cache entries retain their inode identities;
mtime is deliberately touched by cache access. Positioned E3001/E3013/E3012 checks pass.
The first clean full gate failed only the suite. A detailed rerun isolated an existing REPL
output oracle: inspectContext exposed the executable canonical implementation path. Return the
authored compileSyntax behind the same executable admission guard; do not update the expected
spelling. All other first-run gates pass. Validate the REPL property and rerun the clean full gate.

The REPL description property passes after the repair. The second clean full repository gate
passed every check, including the optimized warning-free build, full suite, provider gate,
engine checks and CLI/tooling checks. The original failing gate and detailed REPL output are
retained as evidence; no expectation was weakened.

Existing feature/734-trait-evidence contains broader unmerged evidence/witness work for #734 and
#735. Preserve and reconcile it with this gate rather than independently reimplementing those
fixes or keeping two competing runtime evidence paths.

Exact next action: merge this bounded repair after required hosted checks pass, then reconcile
the existing trait-evidence work for #734/#735 before further engine implementation.

## Referenced by

[[handoffs/_MOC]] · [[Compiler Literals]] · [[Type Check Method]] · [[Eval Env]]
