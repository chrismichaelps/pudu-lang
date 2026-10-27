---
type: handoff
status: COMPLETE
issue: 552
aliases: [Native Generic Delivery]
---
# Native Generic Delivery

Delivery Owner → Language Architect → Backend Engineer. No subagents, per user
instruction. Semantic and Forensic Guardian review remain promotion gates.

Stacks on 56c34753 (#551). Nothing is merged to dev.

Owned: Core.hs, Backend/Emit/{Aggregate,Frame}.hs, Compiler/Frame/Body.hs,
Compiler/Lower.hs, Compiler/Lower/{Body,Constant,Generic,Match,Method,Record,
Scalar,Signature,State,Tuple,Types}.hs, test/Pudu/Backend/{GenericPrograms,
ModulePrograms,TextLeakSpec,EmitSpec}.hs, both Cabal files and the matching
vault pages. [[Native Generics]] holds the contract.

The fixture sweep caught main lowering to an empty body after a failed
specialization returned no result without refusing. Fixed at the source, and
Body now refuses any construct that stops without a refusal.

Done; #553 (`?`) follows on its own branch. Exact next action there: ranges as values and `for`.

## Referenced by

[[handoffs/_MOC]] · [[Native Generics]]
