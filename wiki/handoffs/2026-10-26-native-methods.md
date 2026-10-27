---
type: handoff
status: COMPLETE
issue: 551
aliases: [Native Trait Method Delivery]
---
# Native Trait Method Delivery

Delivery Owner → Language Architect → Backend Engineer. No subagents, per user
instruction. Semantic and Forensic Guardian review remain promotion gates.

Stacks on 4bd88f64 (#544), whose full gate run happens in a detached worktree.
Nothing is merged to dev.

Owned: Compiler/Lower.hs, Compiler/Lower/{State,Types,Signature,Body,Method}.hs,
test/Pudu/Backend/{MethodPrograms,ModulePrograms,TextLeakSpec}.hs, both Cabal
files and the matching vault pages. [[Native Trait Methods]] holds the contract.

Found on the way: two modules' types of one name share one evaluator method
slot (#550). Its fix goes on its own branch from dev.

Done: the corpus passes in every evidence mode and the backend sweep is clean apart from the cancellation property, which only fails under parallel load. Exact next action: generic functions and implementations by specialization.

## Referenced by

[[handoffs/_MOC]] · [[Native Trait Methods]]
