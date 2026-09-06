---
type: handoff
status: VALIDATED
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

## Sparse bitset STD ownership

Language Architect → STD Implementer. Own lib/Std/BitSet.pudu and its new mirror, STD MOC and
changelog entry. Add UInt64 sparse block membership and algebra consuming existing native scalar
kernels and ordered bulk map construction. Preserve all other source work. The user explicitly
expanded STD scope alongside backend optimization. No measurements, tests, builds or reviews.
Implemented the documented sparse bitset module; remains unvalidated.
Exact next action for this continuation: add a Haskell packed-word kernel for bitset cardinality
and block algebra so STD can avoid per-word evaluator dispatch.

## Word-map reduction ownership

Language Architect → Runtime Implementer. Own Runtime.Word, Eval.WordMap, primitive registration
in Builtin.Definition, Builtin, Call, Install, semantic/type preludes, cabal and mirrored pages;
own Std.BitSet.size consumer. Previous goal turn made progress (2e48c38 pushed). Implement a pure
fallible Word64 reduction over host maps; preserve unrelated work. No validation commands.

Implemented native cardinality and connected Std.BitSet.size. Algebra still runs in Pudu.
Exact next action: introduce checked native block-algebra primitives for Std.BitSet union and
intersection, preserving sorted keys and canonical nonzero words.

## Native block algebra ownership

Runtime Implementer owns Runtime.Word, Eval.WordMap, existing primitive registration modules,
Std.BitSet algebra and their mirrors. Previous turn was progress: a0d2846 pushed. Replace Pudu
block loops with checked native tree algebra. Preserve unrelated changes. No validation commands.

Implemented all four algebra kernels and STD consumers, unvalidated.
Exact next action: move sparse subset/disjoint predicates into short-circuiting host-map kernels
without allocating result maps.

## Native predicate ownership

Runtime Implementer owns Runtime.Word, Eval.WordMap, builtin registration modules and
Std.BitSet predicates plus mirrors. Prior turn made progress: db3557d pushed. Implement
left-first short-circuit host-map predicates without projected/result map allocation.
Preserve other work. No tests, builds, reviews or measurements.

Implemented both native predicates and STD consumers, unvalidated.
Exact next action: remove projected UInt64 input trees from native word-map algebra by fusing
checked payload conversion with tree merging while retaining full-input validation semantics.

## Direct payload algebra ownership

Runtime Implementer owns Runtime.Word and Eval.WordMap plus mirrors and STD representation
notes. Previous turn made progress: 677264e pushed. Remove projected input and encoded-output
intermediate trees, preserving complete left-first validation. No validation commands.

Implemented direct payload-tree merge and retained identity-adapter API for Word64 clients.

## Native sparse word member enumeration & gate validation

Runtime Implementer owned `Runtime.Word`, `Eval.WordMap`, `Builtin.Definition`, `Builtin`, `Call`, `Install`,
`Semantic.Prelude`, `Type.Check.Prelude`, `lib/Std/BitSet.pudu`, and all corresponding wiki mirror pages.
Implemented pure `wordMapMembers` kernel utilizing `unpackWords` with hardware `countTrailingZeros` and
`w .&. (w - 1)` bit clearing. `Std.BitSet.toArray` delegates directly to `wordMapMembers`.
Added comprehensive test fixture `test-fixtures/stdlib/UsesBitSet.pudu` asserting 39 distinct BitSet invariants,
wired into `test/Pudu/Compiler/ProgramSpec.hs`.
Cleaned redundant imports across `Pudu.Eval.Hash`, `Pudu.Eval.Builtin`, `Pudu.Runtime.Word`, and
`Pudu.Runtime.Collection` to ensure zero GHC warnings under `-Werror`.
Ran and passed all 7 CI validation gates in `test/gates.sh`:
- no warnings, optimized (cabal build all --enable-optimization=2 --ghc-options='-Werror')
- full suite, optimized (cabal test all --enable-optimization=2)
- every committed Pudu file is formatted (pudu fmt --check)
- every diagnostic code means one thing (diagnostic-codes.mjs)
- language server answers a real session (lsp-session.mjs)
- language server survives editor inputs (lsp-robustness.mjs)
- documentation site keeps its contract (doc-site-parity.mjs)
Status transitioned to VALIDATED.

## Unboxed contiguous byte buffers and flat hash tables with control metadata

Runtime Implementer owned `Runtime.Buffer`, `Runtime.SwissTable`, `Eval.Buffer`, `Eval.SwissTable`,
`Eval.Builtin.Definition`, `Eval.Builtin`, `Eval.Call`, `Eval.Install`, `Semantic.Prelude`, `Type.Check.Prelude`,
`lib/Std/Buffer.pudu`, `lib/Std/FlatMap.pudu`, and all mirrored wiki pages under `wiki/src/`.
Implemented low-level contiguous byte buffers with unboxed scalar read/write, bulk copy, and vector word scanning.
Implemented high-performance flat hash tables using 1-byte control metadata (empty `0xFF`, tombstone `0xFE`,
7-bit $H2$ fingerprint) with linear triangular probing and automatic rehashing at 75% load factor.
Wired 12 pure builtins across the compiler, evaluator, and type checker.
Added test fixtures `test-fixtures/stdlib/UsesBuffer.pudu` (23 assertions) and `test-fixtures/stdlib/UsesFlatMap.pudu` (31 assertions), testing 100% of public APIs across typical cases, boundary limits (0, max values, unaligned offsets), tombstone recycling, polymorphic values (`FlatMap[Str]`), and 60-entry bulk rehashing, adhering strictly to flat helper routines with the try operator `?` to avoid nested matches.
Wired both fixtures into `test/Pudu/Compiler/ProgramSpec.hs`.
Ran and passed all 7 CI gates in `test/gates.sh` cleanly without warnings under `-Werror`.

## SWAR 8-slot parallel group probing in flat hash tables

Runtime Implementer owned `Runtime.SwissTable` and its mirrored page `wiki/src/Pudu/Runtime/SwissTable.md`.
Implemented hardware-level SWAR (SIMD Within A Register) parallel group probing:
- `matchByte`: evaluates 8 control bytes simultaneously against target $H2$ fingerprint using bitwise arithmetic in a single machine cycle.
- `matchEmpty` & `matchDeleted`: detect `0xFF` (empty) and `0xFE` (tombstone) slots across the 64-bit control word in parallel.
- `countTrailingZeros`: extracts matching byte offsets with zero branching, replacing single-slot linear probe loops with 8-slot group steps.
All 7 CI quality gates passed cleanly under `-Werror`.

## Hardware memory extensions and vectorized columnar database engine

Runtime Implementer owned `Runtime.Buffer`, `Eval.Buffer`, `lib/Std/Buffer.pudu`, `Runtime.Column`, `Eval.Column`, `lib/Std/Column.pudu`, `pudu.cabal`, `Eval.Builtin.Definition`, `Eval.Builtin`, `Eval.Call`, `Eval.Install`, `Semantic.Prelude`, `Type.Check.Prelude`, and all mirrored wiki pages under `wiki/src/`.
- Extended `Std.Buffer` with hardware-speed memory operations:
  - `readI64`, `writeI64`: two's-complement 64-bit integer representation.
  - `readF64`, `writeF64`: zero-overhead hardware register bit-casting via `GHC.Float.castWord64ToDouble` and `GHC.Float.castDoubleToWord64`.
  - `readU32`, `writeU32`: little-endian 32-bit integer scalar memory operations.
  - `fill`: contiguous memory block initialization (memset semantics).
  - `compare`: lexicographical block ordering comparison (memcmp semantics).
- Designed and implemented native vectorized columnar database engine in `Pudu.Runtime.Column`, `Pudu.Eval.Column`, and `Std.Column`:
  - `ColumnU64`: Contiguous column record pairing unboxed scalar memory with a bit-packed null validity bitmap.
  - `createU64`, `appendU64`, `appendNullU64`, `getU64`, `isNull`: unboxed column construction and bounds-checked retrieval.
  - `sum`, `min`, `max`: hardware-accelerated vector reductions skipping null rows at memory-bus speeds.
  - `filterGt`: branchless SIMD/SWAR predicate filtering producing packed 64-bit word selection masks.
  - `project`: zero-copy gather into contiguous unboxed column preserving null validity.
- 100% public API testing with triple-slash LSP documentation and modular helpers without nested matches:
  - Expanded `test-fixtures/stdlib/UsesBuffer.pudu` to 27 assertions covering all 8 new buffer operations and edge cases.
  - Created `test-fixtures/stdlib/UsesColumn.pudu` with 9 assertions covering full columnar workflow, null handling, aggregations, filtering, and projections.
  - Wired into `test/Pudu/Compiler/ProgramSpec.hs`.
- Formatted all Pudu source files via `pudu fmt`.
- Ran and passed all 7 CI quality gates in `test/gates.sh` under `-Werror`.
Exact next action: continue backend hardware specialization into unboxed float/decimal columnar vectors or memory-mapped table scans.



