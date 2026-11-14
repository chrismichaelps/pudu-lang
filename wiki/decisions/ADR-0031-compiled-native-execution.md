---
type: decision
status: PROPOSED
date: 2026-11-14
tags: [decision, native, performance, mobile, ui]
aliases: [Compiled Native Execution, ADR-0031]
---

# ADR-0031 — Compiled native execution: direct calls, compiled views, one-crossing frames

## Context

[[Pudu Native]] puts application logic, the reconciler, layout and event dispatch in Pudu,
emitted as C11. Three costs decide whether that is fast on a phone:

1. **Every call allocates.** [[Native Execution Frames]] runs each call through the frame
   dispatcher: the body returns a step record, the dispatcher validates it, allocates and
   zeroes a heap frame, retains each owned argument, calls the callee through the function
   table, and frees the frame on return. That cost buys unbounded recursion depth on a fixed
   host stack and exact unwinding, and it is paid by every call, including a two-line leaf.
2. **A view tree diff is proportional to the tree, not to the change.** Rebuilding a view
   description and comparing it with the previous one touches every node on every commit.
3. **Crossing to the platform per property** multiplies the boundary cost by the number of
   changed properties.

Pudu has facts a dynamic runtime lacks: the whole program is one C translation unit, every
type is known, values are immutable and reference counted, and the call graph is static.
This decision uses those facts.

## Decision

### 1. Direct calls

A function is **direct** when the compiler proves its call depth is bounded:

- it is not the entry and is never reached as a function value (no closure record);
- it makes no call through a function value;
- it is in no call cycle, and every function it calls is direct;
- its frame is at most 512 cells, and the deepest chain of direct frames below it fits in
  64 KiB of host stack.

A direct function runs in a frame on the C stack with the same layout as a heap frame, linked
into the active chain, so unwinding, owned-slot release, blame and call-depth failure (E7002)
behave exactly as on the heap path. A call to a direct function, from any body, is a plain C
call: no step record, no table dispatch, no allocation. Its block jumps use a local program
counter, so the C compiler turns them into direct branches. Recursive functions, functions
reached by value and oversized frames keep the heap path, which stays the reference.

The function table keeps a body for every function, so a direct function reached later
through a value still runs; that body forwards to the same compiled code.

Exported functions call their direct body directly, so a host call into Pudu costs the
admission checks plus one C call.

### 2. Compiled views

A view function's output is split by the compiler into a **skeleton**, the nodes and
properties fixed by the source, and **holes**, the values that depend on the model. For each
view the compiler emits a create routine for the skeleton and an update routine that compares
only holes. Conditionals become regions that swap; iteration becomes keyed regions. A commit
costs the holes it inspects and the changes it finds, not the size of the tree.

Hole comparison exploits immutability: two shared values with the same address are equal
without inspecting them, so an unchanged subtree of the model is skipped by one pointer
compare. Text compares by address first, then by length and bytes.

### 3. One crossing per frame

A commit writes one flat instruction stream: fixed-width operation words, node identities
that index a dense table in the platform adapter, property identities from a compile-time
constant table (never names), and text as UTF-8 address and length. The stream lives in two
arenas reused on alternate commits, so a steady-state frame allocates nothing. The adapter
applies the stream in one call. Platform events enter through one C function into an input
ring; inputs are reduced and committed at most once per display refresh.

### 4. A first frame in read-only data

When the initial model is a constant, the first frame's instruction stream is computed at
build time and stored as read-only data; cold start applies it without running the view code.

### 5. Arena-lived view descriptions

View descriptions live for one commit. When the checker proves a description does not escape
the commit, it is allocated from the commit arena with no reference counting and released by
resetting the arena. The model and the previous hole values are the only state that persists.

### 6. Build-time size and code layout

Failure and refusal paths are marked cold so hot code stays dense; the single translation
unit gives the C compiler the whole program for inlining; unused runtime parts are never
emitted.

## Evidence required

Each section lands with a measured comparison at `-O2`: direct calls against the heap path
and against a hand-written C function; commit time and allocations per frame for a list
screen with one changed row; cold start to first frame and binary size for the counter
application; recorded on named simulators first and named devices before any performance
claim.

Section 1 measured (#904): a non-recursive scalar call went from about 57 ns on heap frames to about 14 ns as a direct call, against about 4 ns for hand-written C; see [[Native Direct Calls Delivery]].

## Resolved Grill Log

- **Q:** Remove the heap frame path? **A:** No. _Rationale:_ it is what makes unbounded
  recursion safe on a fixed stack. _Rejected:_ host-stack recursion with a raised stack
  limit.
- **Q:** Unlink direct frames from the active chain to save two stores? **A:** No.
  _Rationale:_ unwinding must release their owned slots and blame must see the right frame.
  _Rejected:_ a fast path with different failure behavior.
- **Q:** Diff complete view trees with structural sharing? **A:** No. _Rationale:_ the
  compiler already knows which parts can change. _Rejected:_ a runtime tree differ as the
  primary path.
- **Q:** Name properties by text in the stream? **A:** No. _Rationale:_ identities from a
  constant table make the adapter a jump table. _Rejected:_ name lookup per property.
- **Q:** Promise performance before measurement? **A:** No. _Rationale:_ every section has a
  measured gate. _Rejected:_ unmeasured claims.

## Referenced by

[[decisions/_MOC]] · [[Pudu Native]] · [[Native Execution Frames]]
