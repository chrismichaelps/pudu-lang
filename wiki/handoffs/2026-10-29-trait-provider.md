---
type: handoff
status: ACTIVE
aliases: [Trait Provider Delivery]
tags: [handoff, compiler, semantics]
---
# Trait Provider Delivery

Issue #742 starts on fresh feature/742-trait-provider-schemes from fetched dev. Scope owns Method
provider-scheme registration, Call nominal trait selection, the CLI gate/registration and mirrors.
Preserve all #739 branches and existing #734 work. Architect resolves canonical provider identity;
Semantic Engineer repairs selection; Tooling/Release validates. No delegated agents. Tested engine prerequisite merges are now authorized.
The project owner waived independent review for this engine delivery loop on 2026-10-30.
Merge follows successful required checks.

A known Int receiver made TextWire.encode type as Int while execution returned text. A literal
receiver masked it. The canonical per-provider scheme must select the explicitly named trait;
ordinary ambiguous calls still refuse. Imported collision (#734) remains a separate repair.

The CLI gate reproduced the known nominal-receiver error before repair. A separate control also
proved runtime generic-bound dispatch chooses the wrong provider; issue #743 records its complete
reproducer and remains required before engine work. This gate keeps generic bound type checking
and explicit nominal runtime selection distinct; it does not claim generic runtime repair.

The per-provider compiler scheme repair is implemented. A clean optimized build has passed;
the first full gate completed with only the new provider gate failing. It exposed a pre-existing
built-in type-owner fallback accepting Int.encode where Box.encode refuses. The new guard checks
recorded ambiguity without changing module/local precedence. The original full log is retained;
the fresh focused build and provider gate now pass the companion repair. The second clean full
gate passed every check.

Integration update: current dev e6377da5 merges with a changelog-only conflict; both histories
are preserved. The original full local gate and hosted checks passed. Revalidate the focused
gate and hosted full checks on the integrated head. Runtime provider repair continues in #743.

Exact next action: validate and merge this compiler prerequisite, then complete #743 before engine continuation.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Method]] · [[Type Check Call]] · [[Trait Provider Gate]]
