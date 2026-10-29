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

## Current verification and integration

The original draft passed clean optimized full validation and hosted checks. Ground support is
separately delivered in draft #723. Nothing is merged. Frame integration exposed missing end
response and budget-time outputs: Architect resolved the amended contract before Runtime Engineer
updated the same owned files. Focused Chrome source study verified that post-impact velocity and
remaining time differ from average applied travel.

Movement now retains response and remainingFraction; a single component-scaled projection updates
response and derives residual by scalar time. Completed moves consume constant-motion time,
including rest after a stop, while retaining post-contact response. This is not an event-time
ballistic integrator. Before final-frame composition, tests cover resumption, endpoint response,
overflowing Euclidean magnitude with finite components and explicit complete underflow refusal.
The shallow-inward regression first exhausted the budget: incoming feasibility incorrectly used
candidate slack. Incoming direction now uses zero slack; rounded candidates retain tolerance.
The focused gate and actual capsule/box adapter pass with baseline and freshly built compilers.
The fresh optimized -Werror build, full suite and every repository gate passed; evidence is in
/tmp/pudu-motion-response-gates.log. Ground #723 hosted checks also all passed.

[[Ark Motion Benchmark]] prior draft: 508 / 519 / 512 ms per 1,000 two-wall moves after 100 warmup,
median 512 ms. Quiet final runs after full validation: 410 / 409 / 422 ms, median 410 ms (about 20%
lower), with checksum 5000.0 and warmup 500.0 unchanged. This is local interpreter timing including
query callbacks and response validation, not native scene throughput.

Delivery continues in draft PR [#721](https://github.com/chrismichaelps/pudu-lang/pull/721).
Role transition: Runtime Engineer completed validation; Tooling/Release publishes the refinement.
Exact next action: compose gravity/movement/support into frame-controller behavior using validated
response and budget-time outputs. Do not merge.
Independent implementation, Language Architect and Forensic Guardian reviews remain required.

## Referenced by

[[handoffs/_MOC]] · [[Ark Engine]] · [[Ark Swept Motion]]
