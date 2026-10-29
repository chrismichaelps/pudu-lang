---
type: handoff
status: ACTIVE
issue: 660
aliases: [Ark Physics Continuation]
tags: [handoff, ark, physics]
---

# Ark Physics Continuation

Continue the existing engine integration branch and its unfinished physics slice. Role transitions:
Architect → Library Engineer → Test Engineer → independent Language Architect and Forensic Guardian.
Own admission/velocity repairs in `lib/Ark/Physics.pudu`, overflow coloring in
`lib/Ark/Physics/Step.pudu`, the new boundary fixture and corresponding mirrors. Preserve the
existing physics implementation, demo, benchmark and mesh work from the preceding session.
Also own `test/ark-physics.mjs`, its CI/local registrations and the Cabal nested-physics shipping
entry. Source-distribution evidence exposed the missing nested glob; the gate now checks all four
modules rather than relying on checkout resolution.

Observed defects: NaN materials, fabricated shapes and infinite inverse masses enter body lanes;
velocity updates admit non-finite values; the contact color mask merges overflow contacts into
one batch despite shared bodies. These require boundary rejection and disjoint overflow batches.
Existing physics scenarios and optimized render conformance pass. The installed runtime now
resolves to the current optimized build; no full gates were run locally.

Repairs now pass the focused physics gate (scenarios, exact boundary output, formatter, positioned
E3001 refusal and source archive contents). Engine dependency validation reports 27 modules and
zero findings. Independent review discovered an additional overflow when two finite inverse masses
are summed; constraints now normalize both inverse masses by their maximum before solving, which
preserves the common-scale cancellation and keeps their sum in [1, 2]. The two-tiny-mass regression
preserves elastic velocities instead of producing NaN.

Final independent implementation, public API and Forensic Guardian review approved the repair
scope. The reviewer independently ran the physics gate, shell syntax and whitespace checks with
no unresolved findings. Review covers the admission, constraint and batching repairs, not every
remaining engine feature. The scenario/demo/benchmark mirrors now describe their measured scopes.

Exact next action: partition the physics delivery into reviewable dependency-ordered commits and
pull requests once its engine foundation dependencies are integrated.

## Referenced by

[[handoffs/_MOC]] · [[Ark Physics]] · [[Ark Physics Step]] · [[Ark Physics Boundary Fixture]]
