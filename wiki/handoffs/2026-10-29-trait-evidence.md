---
type: handoff
status: ACTIVE
aliases: [Trait Evidence Delivery]
tags: [handoff, semantics, runtime]
---
# Trait Evidence Delivery

Issues #734 and #735 run together on feature/734-trait-evidence from dev. Scope owns trait
evidence from checking to dispatch: [[Syntax Tree]] evidence, [[Type Env]], [[Type Check Method]],
[[Type Check Call]], [[Compiler Pipeline]], [[Eval Env]], [[Eval Program]], [[Eval Install]],
[[Eval Call]], [[Eval Call Path]], [[Eval Call Evidence]], [[Eval Compile]], their regressions and
vault pages. Role transitions: Language Architect fixed the rule in [[architecture/SEMANTICS]];
Semantic Engineer recorded evidence and relaxed the declaration refusal; Runtime Engineer made both
evaluators dispatch through it. Reviews remain pending.

Both bugs are one gap: traits were erased at run time. Installation bound `<Type>.<member>` (last
install wins) and dispatch used the receiver's owner and the member name only, so two traits
sharing a member for one type ran whichever installed last (a same-module pair already did so
silently: `shown[T: Show2](&1)`, typed `Str`, answered `7`), and a generic implementation reached
through a bound had no parameters bound. The native C backend is not on dev; its stack must
consume `moduleEvidence` for trait dispatch and witnesses when it lands.

Exact next action: obtain independent implementation, Language Architect and Forensic Guardian
reviews on the PR.

## Referenced by

[[handoffs/_MOC]] · [[architecture/SEMANTICS]] · [[Eval Call Evidence]]
