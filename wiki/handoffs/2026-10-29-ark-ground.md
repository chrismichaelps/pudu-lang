---
type: handoff
status: ACTIVE
aliases: [Ark Ground Delivery]
tags: [handoff, ark, physics]
---
# Ark Ground Delivery

Issue #722 on fresh feature/722-floor-support from fetched dev owns Ground.pudu, UsesArkGround,
ark-ground.mjs, GroundBench and packaging/gate registration plus matching mirrors/MOCs/changelog.
Preserve other checkouts and open engine/compiler PRs. Role transition: Architect resolved
[[Ark Capsule Support]] before source; Runtime Engineer implements it. Independent implementation,
Language Architect and Forensic Guardian reviews remain pending; no self-approval or delegated agents.

Focused authenticated Chrome study examined landing validity, lower hemisphere rejection,
gravity-horizontal footprint and slope classification. Continue focused browser source study for
each subsystem; no large clones/downloads, external implementation text or product names in artifacts.

Settlement provides floor support and Walking/Falling transitions after movement; gravity integration,
full-frame movement and stepping remain open. #719 is an optional overlay integration partner,
not a runtime dependency, and no PR is merged.

Focused analytic/output/positioned-refusal, formatter/lint and source-archive checks pass with
baseline and repaired optimized compilers. The actual finite-box capsule adapter passes floor snap,
finite-edge loss, rising bypass and initial-overlap payload propagation. Numeric tests cover
swept endpoints, under-resolved geometry/tolerance and overflowing velocity projection.

A consecutive oblique-settlement regression first failed: horizontal projection residue falsely
triggered rising. Use 16*epsilon times the absolute dot-product terms, scaling each before the sum.
The regression now passes while true 1e-200 up speed alongside 1e100 perpendicular speed bypasses
the probe. No fixed world-speed deadzone was added.

Aligned arbitrary-gravity floors at minUpDot=1 also exposed a dot-rounding refusal. Slope
classification uses the same term-relative arithmetic bound and still refuses a wall when the
configured positive slope threshold is 1e-200. Both regressions pass before the full gate's fixture phase.

The first full gate passed behavior/build/suite but refused five undocumented exported types.
Each now has a concise source description; targeted API coverage passed with zero undocumented
exports. The fresh optimized -Werror build, full compiler suite and every repository gate passed in
/tmp/pudu-ground-gates-final.log. The freshly built compiler also passed the finite-box overlay.

[[Ark Ground Benchmark]] quiet final runs with the freshly built optimized compiler: 226 / 224 /
226 ms per 1,000 settlements after 100 warmup, median 226 ms. Consumed checksums 5000.0 and
warmup 500.0 agree. This measures the local interpreter including the analytic callback, not native
scene throughput. The first failed gate log remains /tmp/pudu-ground-gates.log.

Role transition: Runtime Engineer completed focused/full validation; Tooling/Release publishes the
draft for independent implementation, Language Architect and Forensic Guardian review.

Exact next action: resolve the frame-controller contract for gravity/terminal velocity, impact
response velocity and remaining simulation time, then compose complete frame movement and support.

## Referenced by

[[handoffs/_MOC]] · [[Ark Engine]] · [[Ark Capsule Support]]
