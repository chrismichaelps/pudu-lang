---
type: architecture
tags: [architecture, backend, native, ownership]
aliases: [Native Ownership]
---

# Native Ownership

Issue #995. Native code keeps values shared that a program holds alone, so the
runtime's in-place paths for trees and arrays never run. This page records how
native calls and locals hand ownership along instead of adding references.

## Sources of extra references

- The caller keeps a local alive in a temporary through a call that borrows it.
- Callee entry retains every owned parameter while the caller still holds the
  argument.
- Each read of a local retains, including its last.
- Primitive bodies read record fields into locals before updating them.

## Caller move

An assignment whose right side is a call that borrows the assigned local, with
no other operand reading that local, passes the local by move. The local is
empty until the assignment stores the result. A failure inside the call ends
the program or the task that owns the local, so no code observes the empty
local.

## Argument transfer

A call argument produced by a move is transferred. The caller moves the cell
into the outgoing argument area and clears its own slot. A thread-local transfer
mask names the transferred argument positions; the callee's entry reads and
clears it and skips the retain for those parameters, so the callee holds the
only reference. The heap path carries the mask in the call step and the
dispatcher sets it before creating the frame; the direct path sets it before
the direct call. Every other entry sees an empty mask.

Only counted aggregates move: arrays, maps, sets, stores and records. A typed fast entry borrows its arguments, so a direct function enters its fast form only when no transfer is pending. The mask names the first 32 positions; a later moved argument is copied and retained.

## Later steps

[[Compiler Lower Tail Move]] moves the final read of a counted local in a function's tail. [[Backend Emit Multi Map]] updates a MultiMap record held once in place: it takes the key's array out of an exclusive tree path, appends to it, and inserts into exclusive trees.

## Measurement

`bench/eval/MultiMap.pudu` with the optimized compiler (-O2) on Apple Silicon,
five samples: native 542 ms minimum / 548 ms median (executable runtime only),
tree 699/700 ms and compiled 702/703 ms (startup, checking and runtime). Before
the ownership work the fixture measured native 3446 ms against evaluator
830 ms. Maps measured 93 ms natively against 791/797 ms tree and 594/599 ms
compiled, and Records 41/42 ms against 435/439 ms and 437/444 ms (three samples
each). Every native row is now below both evaluators. [[Runtime Benchmark]]
builds each native fixture once, reports that build beside the samples, and
labels the two scopes.

## Referenced by

[[NATIVE-PERFORMANCE]] · [[NATIVE-EMISSION]] · [[handoffs/2026-11-24-native-ownership]]
