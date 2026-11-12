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
Eval.Call currently prepares arguments first, and Lower.Lambda/Loan explicitly
mirror that behavior. Member receivers require the same once-held preparation;
qualified trait selection may depend purely on the first supplied value. Inspect
all call planners before changing source, including compiled and loop paths.

The semantic header contained two versions; retain one 2.0.1-draft clarification
after the existing 2.0.0-draft namespace revision. Implementation is still pending,
and the native ledger's #828 obligation must remain Partial until evidence exists.

Inventory findings: Eval.Compile's general path delegates to Eval.Call; closed
module calls and loop kernels cache immutable targets only under lexical/callee-
prefix admission proofs. Eval.Call.Path.qualifiedCallee uses the first argument
to disambiguate declared/builtin owners, so moving it before arguments with an
empty list would change dispatch. Separate runtime preparation from pure selection.
Lower.Lambda and Loan.Through explicitly run their target after operands.
Lower.Method runs argument declarations before receivers; lower built-in methods
also rely on receiver-last Core sequencing, and Array's map/filter/reduce/sortBy
expansions explicitly declare callbacks before receivers. Audit every expansion;
changing only one frame operation would leave these paths inconsistent.

Architect → Runtime Engineer → Backend Engineer → Test Engineer. The first
partition owns [[Eval Call]], [[Compiler Lower Lambda]], [[Compiler Lower Loan]],
[[Backend Closure Programs]], [[Backend Mutable Loan Programs]],
[[Backend Text View Programs]] and their
mirrors. Ordinary runtime function values are prepared before arguments in
both evaluators and native lowering. Member and qualified dispatch remain
outside this partition.

Exact next action: prepare member receivers and their callable selections
before arguments across evaluator and native method paths, including builtin
expansions and loaned places. Establish when the array receiver may be moved
without changing an argument that reads its binding.

## Referenced by
[[handoffs/_MOC]] · [[Callee First Call Evaluation]]
