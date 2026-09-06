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

## Shared scalar bounds continuation

Own IntegerLiteral, Eval.Operator and their mirrors. Checked arithmetic, saturation and literal fit checks now share inclusive kind bounds, using constant signed intervals and existing unsigned masks. No measurements, tests, builds or reviews run.

## Native wrapping carriers

Integer wrapping now dispatches admitted 8/16/32/64-bit kinds through explicit Haskell native carriers. Wider kinds retain exact masks and shared signed bounds. This is an internal modular-arithmetic implementation, not an implicit surface conversion. No measurements, tests, builds or reviews run.

## Native modular arithmetic continuation

IntegerLiteral and Eval.Operator now compute wrapping add/subtract/multiply in Word64 for admitted widths up to 64, then reinterpret at the declared width. Wider and unbounded arithmetic retain exact fallback. Checked/saturating paths remain unchanged. No measurements, tests, builds or reviews run.

## Internal collection API ownership

Runtime Implementer owns Runtime.Collection, Eval.Keyed and Eval.HashMap integration, manifest registration and mirrors. Map/Set bulk construction and Map/Set/HashMap enumeration now consume one internal evaluator-independent API. No measurements, tests, builds or reviews run.

## Bidirectional bulk loading

Own Runtime.Collection and its mirror for monotone-direction detection. Map and Set consumers now bulk-load descending as well as ascending prefixes, preserving first representatives and latest map payloads. No measurements, tests, builds or reviews run.

## Balanced run assembly continuation

Runtime.Collection now bulk-builds every monotone run and combines chronological groups through a binary carry stack. Map/Set adapters consume it without changes. No measurements, tests, builds or reviews run.

## Native bitwise kernel delivery

Own IntegerLiteral, Eval.Operator and their mirrors. Implemented bounded AND/OR/XOR/complement with native-word dispatch and exact wider fallback. This completes the edit interrupted by the earlier approval-service usage limit. No measurements, tests, builds or reviews run.

## Immutable seed continuation

Own Eval.HashMap and its mirror. Removed the unused mutability of the process bucket seed and the IORef read inside mixing. Existing entropy initialization/fallback remains. No measurements, tests, builds or reviews run.

## Native shift continuation

Own IntegerLiteral, Eval.Operator and mirrors. Bounded shifts now use native word carriers after existing count validation; unsigned right shifts normalize first and signed right shifts retain arithmetic behavior. No measurements, tests, builds or reviews run.
