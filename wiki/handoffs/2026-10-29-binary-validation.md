---
type: handoff
status: ACTIVE
aliases: [Binary Validation Delivery]
tags: [handoff, stdlib, serialization]
---
# Binary Validation Delivery

Issue #739 acceptance partition continues on feature/739-binary-validation after native
PR #741 and the facade partition on feature/739-binary-derives. Own UsesBinary, ProtocolSpec
registration, BinaryBench, CLI gate extension and matching mirrors. Preserve predecessor scopes.
Role transition: Architect defines exact-bit/evolution oracles; Runtime Engineer validates the
boundary; Tooling/Release measures and publishes. No delegated agents. The project owner waived independent review for this engine delivery loop
on 2026-10-30 and authorized tested merges to dev. Merge follows required checks.

The API uses Binary.Encode/Binary.Decode with pack/unpack methods and coexists with JSON derives.
The skipped sum-field regression failed before its repair. The complete fixture passes 22 asserted
groups, including exact floating bits in scalars, contiguous arrays and lane blocks, Int extremes,
field naming, sum forms, evolution, wire goldens and typed refusal paths. Required-field removal
is explicitly one-way: a reduced schema reads old data; the old schema refuses new missing data.

The native properties and preceding clean full gate passed on the working continuation. The
complete CLI gate passes output, schema/bit regressions, positioned refusal and actual source
archive inspection. The shared program family passed again with the extended float-block cases;
lint and formatter checks pass. [[Binary Serialization Benchmark]] records the consumed 1,000-entity
workload, three-run measurements and byte-size tradeoff. Raw evidence is in the local Desktop
stage-check folder. A bounded archive source study informed validation; no external code was copied.

Delivery remains staged: #741 validates its writer-corrected integration; the current facade
partition waits for that native prerequisite before a dev-targeted PR. This acceptance partition
then follows the facade.
Keep review diffs below 600 lines and #739 open until every partition is delivered. The complete
engine goal and Ark archive integration (#732) remain outstanding.

Acceptance delivery is pushed at b151a177; required-field-removal regressions and the precise compatibility wording also pass the complete CLI gate.

Exact next action: advance the dev-targeted PR sequence after prerequisite integration.

## Referenced by

[[handoffs/_MOC]] · [[Std Binary]] · [[Std Binary Fixture]] · [[Protocol Evaluation Spec]] · [[Binary Serialization Benchmark]]

Integration update: preserve the complete acceptance fixture and benchmark while merging the
current facade 9d6f22a4, its native writer-boundary repair and merged #742 prerequisite. Keep the
full validation backlinks and new writer admission contract together. Rerun the 22-group fixture,
CLI/distribution gate and consumed comparison against the current optimized compiler before delivery.

The native codec merged in PR #741 as e26a8903d after every hosted check passed. Integrate the
current facade b357f201 with merged #742/#743 and finite writer extents. The repeated-field
reader fixture now assembles malformed bytes independently; the writer correctly refuses the
invalid tree. All 22 groups, consumed benchmark, public writer refusals and distribution checks
pass through both evaluators with the combined optimized compiler. Owner-identity defect #761
remains required before further Ark integration; refresh full acceptance validation before delivery.

The refreshed consumed benchmark at compiler b357f201 measures binary write/read 30.778/54.246 ms
and JSON 35.392/97.458 ms (three sequential five-operation run means, M1, 8 GiB). Sizes remain
140,995/130,012 bytes. Exact raw results and compiler/program hashes are retained locally.
