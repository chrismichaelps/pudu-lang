---
type: handoff
status: IMPLEMENTED_UNVALIDATED
tags: [handoff, performance]
---
# Backend Specialization Track

The user replaced the app/DB feature track with exclusive low-level backend performance work.
Language Architect → Runtime Implementer. Own Eval.Keyed and its mirror for adaptive bulk loading;
own BACKEND-SPECIALIZATION design. Preserve concurrent FFI edits. No transaction implementation
was started. Prior database work is committed; it is not the active workstream.

Implemented verified-prefix bulk Map/Set construction and strict fallback accumulation. No tests,
builds, benchmarks or reviews run, as directed. Complexity arguments are not speed measurements.

Exact next action: introduce a phase-owned StoragePlan representation with scalar width, key-order,
lifetime and fallback evidence, connected to the actual lowering pipeline.

## Referenced by
[[handoffs/_MOC]] · [[Backend Representation Specialization]] · [[Eval Keyed]]

## Packed-byte continuation

Own Eval.Bytes and its mirror. Removed list staging in byte/array conversions using known-length sequence generation and ByteString unfolding. Validation remains ordered and complete. No measurements, tests, builds or reviews run. The planned StoragePlan remains future work; the current tree exposes evaluator modules rather than an implemented lowering/codegen directory.

## Sequence kernel continuation

Own Eval.Array and its mirror. Array search now stays in the sequence; pop uses a right view and position edits use direct sequence operations. Public boundary guards remain intact. No tests, builds, reviews or measurements run.

## Higher-order sequence continuation

Own Eval.Builtin and its mirror for sequence-native map/filter/reduce. Removed intermediate list conversion while preserving callback order and failure short-circuiting. No measurements, tests, builds or reviews run.

## Direct enumeration ownership

Own Eval.Keyed, Eval.Builtin, Eval.HashMap and their mirrors for direct ascending sequence construction. Maps no longer create association lists for value enumeration. Set and bucket enumeration also avoid transient lists. No measurements or validation commands run.

## Integer hash specialization

Own Eval.Hash and its mirror. Added a checked Word64-magnitude path that mixes directly without list or byte-buffer staging. General Integer hashing avoids the packed intermediate buffer. Byte order, zero and sign encoding are retained. No measurements, tests, builds or reviews run.

## Text hash continuation

Eval.Hash now feeds canonical UTF-8 bytes directly from Unicode scalars, avoiding explicit encoded ByteString construction in the text hashing path. Rendered fallback values share it. No normalization or hash encoding changes intended; no measurements, tests, builds or reviews run.

## Wrapping kernel ownership

Own IntegerLiteral and its mirror for mask-based fixed-width wrapping, consumed by existing runtime arithmetic and bit operations. Shared admitted-width masks replace general remainder; checked arithmetic remains unchanged. No measurements, tests, builds or reviews run.
