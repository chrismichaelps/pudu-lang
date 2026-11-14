---
type: handoff
status: IN_REVIEW
issue: 661
aliases: [Square Root Delivery]
tags: [handoff, math, performance]
---
# Square Root Delivery

Fresh feature/661-full-range-sqrt starts from fetched development including merged CI transport
#656. Earlier engine foundation/graph and LSP work remain reviewed in their feature branches;
matrix #660 is committed locally with reviewed prerequisites and will be published after their
integration. No unrelated edits or build products are removed.

Role transitions: Language Architect → Library Engineer → Test/Performance Engineer → independent
Language Architect and Forensic Guardian. Library Engineer owns only Std/Math/Float.pudu sqrt;
Test/Performance Engineer owns sqrt-range.py, RootKernels.pudu and focused CI/gate registration.
Architect owns resolved mirrors and navigation. Mirrors precede source changes. Responsibility
review retains scalar sqrt in its existing module below 500 lines despite the larger local edit.

Observed outputs: sqrt(1e300) gave about 4.77e293; sqrt(1e-300) about 9.54e-7. The whole
module was software: `trunc` looped per bit, `ln` looped once per halving, trigonometry used
truncated polynomials. A normalized Newton root fixed range but was still neither correctly
rounded nor fast enough for engine math.

Design revision (Language Architect): the resolved "no host math" constraint is withdrawn. One
closed [[Float Kernel Identity]] enumeration drives the evaluator, checker and resolver;
[[Runtime Float Kernels]] implements it with the hardware root and C math library. Public
signatures and `Option` domains are unchanged and decided in Pudu. Exact kernels (sqrt, floor,
ceil, trunc, round, fma, bit casts) are bit-identical across IEEE platforms; platform kernels
are documented as last-bit platform-dependent. New public functions: `fma`, `toBits`, `fromBits`, and (#665) `fromInt`/`toInt`, which replace
the doubling loop in Std.Stats.
Branch includes the #662 parser repair, which the golden corpus needs to parse.

Evidence: 762 golden inputs (subnormals, powers and neighbours across all exponents, 1e±300,
maximum finite, random bit patterns) match host sqrt bit for bit. Exact-kernel contracts,
domain refusals and an integer-argument type refusal pass; the 20 existing Float math checks pass.
At -O2, a 2,000-iteration sqrt+floor+sin loop fell from 90 ms to 8 ms. Reciprocal root: `1 / sqrt`
4 ms median; bit estimate with one refinement 16 ms (0.18% error), two 17 ms (4.7e-6 error).
The estimate is rejected as an engine path. No full gates were run locally, by request.

Exact next action: publish the matrix slice (#660) on top of reviewed foundations, then
continue Ark Core: containers, allocation tracking and the archetype store.

## Referenced by

[[handoffs/_MOC]] · [[Std Math Float]] · [[Runtime Float Kernels]] · [[Square Root Range Gate]] · [[Root Kernel Benchmark]]
