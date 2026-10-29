---
type: handoff
status: ACTIVE
aliases: [Ark Motion Delivery]
tags: [handoff, ark, physics]
---
# Ark Motion Delivery

Issue #720 owns Physics/Motion.pudu, UsesArkMotion.pudu, ark-motion.mjs, MotionBench.pudu,
manifest/gate registration and matching mirrors/MOCs/changelog, on fresh feature/720-query-movement
from fetched dev. Preserve other checkouts and the unmerged shape/movement/compiler PRs.

Role transition: Architect resolved [[Ark Swept Motion]] before source; Runtime Engineer owns
implementation. Independent implementation, Language Architect and Forensic Guardian reviews remain
pending; no self-approval, delegated agents or merge.

Authenticated Chrome source study examined contact sliding, multiple-wall adjustment and gravity-
relative walkability. Use focused source studies for every engine subsystem; never clone/download
large trees or introduce external implementation text/product names in repository artifacts.

The query callback keeps the solver independent of unmerged #719. Validate actual integration in
a temporary overlay using that finite-box query, as well as a standalone analytic fixture.
Walking/falling and floor support remain open; this slice provides their geometric movement seam.

Focused fixture, positioned refusal, formatting/lint and actual source archive pass. The finite-box
adapter verifies a non-point capsule against two finite obstacles, rounded-edge sliding, out-of-bounds clear travel and
preserved initial-overlap payload. Both baseline and repaired compilers execute the standalone gate.
The fresh clean optimized -Werror build, full compiler suite and every repository gate passed.
The freshly built baseline compiler also passed the non-point capsule overlay integration gate.

[[Ark Motion Benchmark]] baseline mixed two-wall moves: 552 / 568 / 554 ms per 1,000 after 100
warmup moves. Reusing the validated near-unit normal length gives 506 / 504 / 504 ms,
median about 9% lower, with identical checksum 5000.0 and warmup 500.0. Local interpreter timing
includes callbacks; this is not native scene throughput. PR #719 hosted checks all passed.

Role transition: Runtime Engineer finished focused/full verification; Tooling/Release publishes
the draft for independent implementation, semantic and vault review.

Delivery: implementation commit `ff6a8ce8` is pushed in draft
PR [#721](https://github.com/chrismichaelps/pudu-lang/pull/721) targeting dev.
Hosted checks and independent reviews remain pending. No PR was merged.

Exact next action: implement gravity-relative floor support and walking/falling transitions over
validated sweep callbacks, beginning with the resolved support/landing contract in the vault.

## Referenced by

[[handoffs/_MOC]] · [[Ark Engine]] · [[Ark Swept Motion]]
