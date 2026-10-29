---
type: handoff
status: ACTIVE
aliases: [Binary Validation Delivery]
tags: [handoff, stdlib, serialization]
---
# Binary Validation Delivery

Issue #739 acceptance partition continues on feature/739-binary-validation after native draft
PR #741 and facade commit 231053a9 on feature/739-binary-derives. Own UsesBinary, ProtocolSpec
registration, BinaryBench, CLI gate extension and matching mirrors. Preserve predecessor scopes.
Role transition: Architect defines exact-bit/evolution oracles; Runtime Engineer validates the
boundary; Tooling/Release measures and publishes. No delegated agents, self-approval or merges.
Independent implementation, Language Architect and Forensic Guardian reviews remain pending.

The API uses Binary.Encode/Binary.Decode with pack/unpack methods and coexists with JSON derives.
The skipped sum-field regression failed before its repair. The complete fixture passes 22 asserted
groups, including exact floating bits in scalars, contiguous arrays and lane blocks, Int extremes,
field naming, sum forms, evolution, wire goldens and typed refusal paths.

The native properties and preceding clean full gate passed on the working continuation. The
complete CLI gate passes output, schema/bit regressions, positioned refusal and actual source
archive inspection. The shared program family passed again with the extended float-block cases;
lint and formatter checks pass. [[Binary Serialization Benchmark]] records the consumed 1,000-entity
workload, three-run measurements and byte-size tradeoff. Raw evidence is in the local Desktop
stage-check folder. A bounded archive source study informed validation; no external code was copied.

Delivery remains staged: #741 is draft/unmerged; the facade branch is pushed and waits for its
native prerequisite before a dev-targeted PR. This acceptance partition then follows the facade.
Keep review diffs below 600 lines and #739 open until every partition is delivered. The complete
engine goal and Ark archive integration (#732) remain outstanding.

Exact next action: commit/push this partition, then advance the dev-targeted PR sequence after prerequisite integration.

## Referenced by

[[handoffs/_MOC]] · [[Std Binary]] · [[Std Binary Fixture]] · [[Protocol Evaluation Spec]] · [[Binary Serialization Benchmark]]
