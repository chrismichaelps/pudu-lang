---
type: handoff
status: ACTIVE
issue: 828
aliases: [Call Order Repair Delivery]
---
# Call Order Repair Delivery

Architect owns the call-order ADR, semantic clarification, bounded implementation
inventory and corresponding mirrors. The implementation assignments are recorded below.
Fresh feature/828-callee-first starts at dev b9038686. Preserve unrelated
untracked build artifacts in this checkout; no subagents.

[[Callee First Call Evaluation]] retains the existing normative callee-first rule.
The original evaluator and lowering prepared arguments first. Runtime callees
and receivers must be held once. Qualified trait selection may depend on the
first supplied value when the selection is pure.

The semantic header retains one 2.0.1-draft clarification after the existing
2.0.0-draft namespace revision. The native ledger's #828 obligation stays
Partial until the complete evidence and reviews are recorded.

Inventory findings: Eval.Compile's general path delegates to Eval.Call; closed
module calls and loop kernels cache immutable targets only under lexical/callee-
prefix admission proofs. Eval.Call.Path.qualifiedCallee uses the first argument
to disambiguate declared/builtin owners, so moving it before arguments with an
empty list would change dispatch. Separate runtime preparation from pure selection.
The original plans ordered receiver, arguments and invocation independently
in declared methods, built-in frame operations and array callback expansions.
The receiver worktree changes all three.

Architect → Runtime Engineer → Backend Engineer → Test Engineer. The published
function-value partition owns [[Eval Call]], [[Compiler Lower Lambda]],
[[Compiler Lower Loan]], [[Backend Closure Programs]],
[[Backend Mutable Loan Programs]] and [[Backend Text View Programs]].

Architect → Runtime Engineer. [[Eval Call]] and [[Eval Builtin String]] separate
member selection from invocation. The preparation partition preserves the
existing member order while making the selected invocation reusable.

Architect → Backend Engineer → Test Engineer. The receiver partition advances
member preparation before arguments and owns [[Compiler Lower Method]],
[[Compiler Lower Lambda]], [[Compiler Lower Loan]], [[Core IR]],
[[Compiler Frame Body]], the built-in lowerings and the backend fixtures.
It preserves loan writeback order and runs conversions after operand effects.
An array move requires arguments that cannot observe the cleared binding or
transfer past the assignment.

Seven explicit receiver traces and diagnostics matched in both evaluators
and native executables. The optimized build and module corpus passed.
The six local shards are in progress.

The preparation partition keeps both exported runtime entry points with their
published signatures: `callMember` prepares and then invokes, keeping its skip of
the owner lookup, and `callStringMethodFast` applies the selection that
`prepareStringMethodFast` makes. Only the internal call path uses the new
preparation directly. The warning-as-error build, the full suite and both format
checks pass on the combined tree.

Exact next action: obtain independent review of the preparation and receiver
partitions on #830, then mark the native ledger's #828 obligation complete.

## Referenced by
[[handoffs/_MOC]] · [[Callee First Call Evaluation]]
