---
type: architecture
tags: [stdlib, views, compatibility]
aliases: [C++ Inspired View Coverage]
---
# C++ Inspired View Coverage

PR #535 adapts useful view and allocation-planning operations to Pudu's
owned values, explicit imports and checked results. The baseline is C++23;
newer working-draft operations are examined separately. This is a capability
comparison, not C++ source compatibility or an identical object ABI.

| Family | Existing capabilities | Completed additions |
| --- | --- | --- |
| Span | Array-backed windows, checked construction, narrowing, positional reads and Sequence terminals | Overflow-safe construction, remaining-tail subspan and reverse traversal through sequence adapters |
| MdSpan | Dynamic extents, row/column/explicit strides, rank-reducing slicing and row-major walking | Checked shape arithmetic; mapping, stride, footprint, uniqueness/exhaustiveness/strided observers |
| StringView | Shared UTF-8 byte slices, substring searches, scalar decoding and lazy splitting | Raw byte access/walking, bounded reverse search, byte-set searches, lexical comparison and checked destination copy |
| Memory | Offset Resource, monotonic Arena and fixed-block Pool | Checked alignment/capacity, lazy pool bookkeeping and bulk reset; accurate ownership limits |
| Iter | Restartable Sequence, ten chained adapters and eager terminals | A composable adapter bridge and chunk, slide, chunkBy, join, buffered reverse and Cartesian product, with ordinary map composition for transform variants |

## Operation mapping and deliberate limits

- C++ begin/end/reverse iterators map to Sequence walks and Views.reverse. Span
  size/empty/front/back/index access, first/last/subspan map to size/isEmpty,
  first/last/get, prefix/suffix/subspan/subspanFrom. sizeof-based size_bytes,
  as_bytes, data pointers and fixed extents need a representation contract absent here.
- Mdspan rank/extent/size/empty/indexing, dynamic stride and mapping observers
  map to Grid and Layout. Every extent is dynamic; rank_dynamic is rank.
  C++ static_extent, always_* type predicates, custom handles/accessors, padded
  layout policies and unchecked multidimensional indexing are outside this dynamic
  Array-backed API. Row/column/explicit-stride layouts and rank-reducing slices remain.
- String-view access, slicing, compare, substring/byte-set searches, copy,
  starts_with/ends_with/contains are available. C++ raw pointer/length and
  char_traits/template overload sets do not map to valid UTF-8 Str. End-item
  methods preserve Pudu scalar semantics; byteAt/byteUnits expose code units.
  Swapping two ordinary view values needs no view-specific operation.
- Monotonic and fixed-block resources reserve aligned caller-storage offsets.
  Upstream heap fallback, polymorphic_allocator, global defaults and synchronized
  pool resources would introduce heap ownership and concurrency contracts beyond
  coordinate planning. checkedPool and reset complete the applicable bounded API.
- Iter filter/transform/take/drop/while/stride/concat/zip/enumerate map to existing
  adapters. Windows/groups/flatten/reverse/product are optional Views adapters.
  keys/values/elements, adjacent_transform and zip_transform compose with map;
  adjacent is slide with a chosen width. join after map is flat-map. common,
  counted, as_const, as_rvalue, ref_view, owning_view and all primarily adapt C++
  lifetime/iterator categories already represented by Pudu ordinary values.
  Unbounded iota/repeat require an explicit overflow/termination contract; bounded
  range/repeat and empty already cover finite factories; single is items([value]). joinWith and arbitrary
  sequence split are not claimed: text splitting has established Str semantics,
  while generic delimiter matching/empty patterns need a separate design. This
  PR does not promise one-for-one coverage of the entire C++ ranges library.

## Resolved Grill Log

- Views retain shared backing values and are read-only snapshots, not raw
  borrowed pointers. Raw pointer access, mutable alias propagation, object
  representation byte casts, static extents, custom C++ accessors and cv/ref
  iterator categories require facilities Pudu does not expose here.
- Memory remains an offset planner over caller-owned storage. It does not
  replace the runtime heap, redirect ordinary allocations, provide a process
  default resource or claim synchronized/shared allocator identity. A Block
  carries coordinates; matching coordinates do not prove resource ownership
  or allocation generation. Invalid and duplicate current-coordinate releases
  are checked without claiming unforgeable handles.
- Existing Pudu narrowing/clamping and Unicode-boundary rules remain. Byte
  searches may return code-unit offsets inside scalars; constructing text
  from such offsets still refuses. No invalid UTF-8 text value is produced.
- Mapping observers use rank-sized metadata. A uniqueness certificate may
  conservatively return false, as the C++ mapping requirements permit; true
  must prove distinct positions. Exhaustiveness follows sorted reachable
  intervals, including zero-stride broadcast dimensions.
- Option-returning constructors and slices reject unrepresentable arithmetic
  before evaluating it. Empty shapes have cardinality zero. No overflowing
  checked Int operation may escape an input-validation path.
- Keep new adapters outside the existing large protocol module. A generic
  `through` method applies an ordinary function to the sequence value, so
  adapter modules import Sequence without a dependency cycle or new syntax.

Index arithmetic follows the currently supported 64-bit target Int. Target
selection is not implemented; the compiler's IntegerLiteral.targetPointerWidth
remains the source of that platform boundary.

## Primary references

- [C++ span](https://eel.is/c++draft/views.span)
- [C++ mdspan interface](https://eel.is/c++draft/mdspan.mdspan.overview)
- [Mapping requirements](https://eel.is/c++draft/mdspan.layout.reqmts)
- [String-view interface](https://eel.is/c++draft/string.view.template.general)
- [Memory resources](https://eel.is/c++draft/mem.res)
- [Range adapters](https://eel.is/c++draft/range.adaptors)

## Referenced by

[[architecture/STDLIB]] · [[Std Views Delivery]] · [[Std Span]] · [[Std MdSpan]] · [[Std StringView]] · [[Std Memory]] · [[Std Iter]]
