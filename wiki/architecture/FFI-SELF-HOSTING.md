---
type: architecture
status: PLANNED
tags: [architecture, ffi, stdlib, compiler]
---

# Foreign Boundary and Self-Hosting Work Remaining

This page is an implementation roadmap, not an expansion of accepted syntax or a claim that all
standard-library primitives exist. [[ADR-0019-getting-a-value-back-out-of-a-library]] and
[[ADR-0020-handing-a-library-a-run-of-bytes]] retain their accepted contracts.

## Delivery order

| Order | Deliverable | Required boundary |
|---|---|---|
| 1 | Complete output ownership | Cancellation-safe transitions; typed cleanup diagnostics; generation identity; all raw products classified before conversion. Admission, refusal, generation identity, discard, result conversion, and cleanup after invalid returned text are covered. A lease cancelled mid-call is given back rather than left in use. What is still unproven is the evaluator's whole masked interval, where the native call, the raw outputs and the claim settle in sequence |
| 2 | Owned values passed by value | Target-derived aggregate layout; explicit resource identity and alias contract; full-value destruction |
| 3 | Returned buffers | Explicit byte length and allocator-matched release; null/empty distinction; overflow checks |
| 4 | Writable buffers | Exclusive call lease; capacity and initialized length; explicit allocation; no mutation of immutable `Bytes` |
| 5 | Callbacks | Registration ownership; lifetime, thread affinity, reentrancy, and quiescent unregister |
| 6 | Hardware operations | Target-specific layout, volatility, ordering, alignment, interrupt and DMA contracts |
| 7 | Self-hosting bootstrap | Source-to-C compiler with reproducible stage comparison, then measured incremental and parallel compilation |

## Owned-by-value design constraints

A struct's pointer fields do not generally identify its destruction obligation. Two returned structs
can share one allocation and own different secondary allocations; equality of the complete pointer
tuple misses that overlap. Conversely, a borrowed internal pointer need not confer ownership at all.
A resource can hold no pointer at all and still need destruction: in `raylib.h` as installed,
`Texture`, `RenderTexture` and `VrStereoConfig` contain only integers, and each has an `Unload*`
that takes it by value. `Texture2D` is among the most used types the library has, so this is the
common case rather than a corner of it — see the amendment in
[[ADR-0021-a-value-the-library-owns]].

The implementation must therefore describe an explicit resource identity and alias/transfer contract,
not infer ownership from every pointer-shaped field. The full native representation must be retained
for a destructor that takes the struct by value. Pointer values remain inaccessible to ordinary Pudu
expressions. Nested aggregate shape, size, alignment, packing, and target ABI classification must be
represented faithfully; a flat list of scalar widths is not a general substitute for aggregate shape.

These constraints require revision and acceptance of issue #227's proposed design before its syntax
can be presented as supported. An explicit C wrapper returning an opaque owned handle remains a
usable binding strategy for libraries whose by-value ownership cannot yet be represented.

## Buffer decisions to resolve

Owned buffers carry a byte length with checked conversion into the host's addressable range and an
allocator-matched release obligation independent of text decoding. A non-null zero-length allocation
still needs release. Null with nonzero length is a contract failure; null with zero length must have a
specified absence/empty rule. Cleanup occurs even when length validation or conversion fails.

Writable buffers require explicit allocation or an exclusive borrow of separately mutable storage.
The native call may initialize only a bounded prefix, and only that prefix becomes readable after
return. Reported lengths larger than capacity are rejected, but that check cannot undo an actual
native out-of-bounds write: the foreign function still bears the declared bounds obligation. Existing
immutable `Bytes` must never become writable through aliases. Element counts, byte counts, and strides
must be distinguished rather than guessed from parameter names.

## Callback and hardware boundaries

Callbacks need an owned registration token. Unregister must prevent new invocations and wait for
in-flight callbacks before captured state or the trampoline can be destroyed. Reentrant unregister
must have a defined non-deadlocking outcome. Foreign threads must attach to an explicit runtime
context; capabilities and failures cannot be inherited implicitly. No host exception may unwind
through a C frame. Cancellation and callback failure require separately defined return behavior.

MMIO requires named target address spaces, supported access widths, alignment checks, and explicit
volatile operations. Volatile access does not imply atomicity, ordering, or a device fence. DMA
requires pinned lifetime and platform cache-coherence operations. Interrupt regions must specify
which operations may allocate, block, panic, or acquire a lock. Ordinary foreign calls provide none
of these guarantees merely by being inside `unsafe(foreign)`.

## Standard-library path to self-hosting

Existing source modules provide useful foundations: `Std.Text.Parse`, `Std.Bytes`, `Std.Text`,
`Std.Map`, `Std.HashMap`, `Std.Set`, `Std.Deque`, `Std.Heap`, `Std.Graph`, `Std.Tree`, `Std.Path`,
`Std.Io`, `Std.Env`, `Std.Process`, `Std.Concurrent`, `Std.Channel`, and `Std.Sync`. Presence is not
proof of completeness, native support, complexity bounds, or structured cancellation.

The continued pass adds `Std.Bytes.Cursor`, `Std.Text.Source`, `Std.Intern`, and `Std.Text.Builder`.
Their mirrors specify cursor failure behavior, byte-column coordinates, session-scoped IDs, and
explicit builder materialization. All four check clean, are formatted, and answer a program that
imports them; none of them has a property suite, and none of that makes a self-hosting SDK.

The compiler should own its token, AST, type, diagnostic, and IR types. They are compiler-domain
modules, not speculative `Std.Ast` or `Std.TypeCheck` APIs. Shared library additions should follow
concrete needs established by implementing these stages:

1. A source reader preserving UTF-8 byte offsets, source identities, line indexing, and stable spans.
2. A lexer and recoverable parser using existing collections and parsers, with symbol interning and
   bounded allocation measured against representative source corpora.
3. Name resolution, type/ownership/effect checking, and structured diagnostics with deterministic order.
4. Core lowering and C11 emission matching the current bootstrap target; file output and linker
   invocation through explicit host boundaries with typed failures.
5. A module cache keyed by source, dependencies, compiler version, target, flags, and ABI contracts;
   atomic artifact publication and corrupt-cache rejection.
6. Parallel module scheduling only after worker lifetime and cancellation are owned by lexical scopes.
7. Stage-zero Haskell compilation of the Pudu compiler, stage-one recompilation of itself, and
   reproducible comparison of artifacts and diagnostic behavior under controlled inputs.

Do not claim sub-second large-project compilation from implementation structure alone. Record cold
and warm timings, allocations, resident memory, dependency invalidation, corpus size, and target
before assigning a throughput claim. No benchmarks were run in the hardening pass.

## Referenced by

[[architecture/_MOC]] · [[architecture/STDLIB]] · [[2026-09-04-ffi-hardening]]
