---
type: handoff
status: ACTIVE
issue: 814
aliases: [Native Word Map Query Delivery]
---
# Native Word Map Query Delivery

Architect → Backend Engineer. feature/814-native-word-map-queries starts at
fresh dev bbc9cdbd. Own Core/Keyed, Lower/WordMap, Runtime/Tree, Emit/Keyed,
Emit/Frame/Value, WordMapPrograms, FrameEmitSpec and corresponding mirrors,
query architecture, navigation and history. Preserve unrelated work; no
subagents. #824's independent full gates continue in its separate checkout.

Resolved scope: all four queries share the existing typed builder and tree
runtime; no new shallow query modules. [[Native Word Map Queries]] owns the
carrier, ordering, width, overflow and cleanup contract. Existing algebra
behavior remains part of focused and full regression coverage.

The first query corpus exposed an unused tree-height helper in standalone
query callables. Height now belongs to tree_node rather than the read-only
base runtime. Final focused word-map checks pass with strict Clang, GCC 15
and ASan/UBSan in both tree and compiled evaluator modes (six configurations).
Each executes nine counted-success programs, exact native/interpreter output,
refusal provenance and located carrier faults. Queries preserve wrapped
member duplicates, UInt128 arithmetic across 2^64, callable identities,
generic keys and source-order transfers. No full-gate or final CI pass is
claimed for this slice yet.

Exact next action: integrate current dev, run the clean optimized full gate,
then publish the bounded query PR and verify its current-head CI.

## Referenced by

[[handoffs/_MOC]] · [[Native Word Map Queries]]
