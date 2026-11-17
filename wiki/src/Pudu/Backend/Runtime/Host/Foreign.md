---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Foreign.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Foreign]
---
# Native Host Foreign

The dynamic loader behind native foreign calls (#850). `pudu_foreign_function`
resolves a declaration's function on its first call, under one lock, into the
wrapper's cache. A library opens with the interpreter's candidates in its
order: the written name, the versioned spellings when a version is written,
then the plain spellings; `c` opens the program itself. A library that does not
open or a symbol it does not export stops the program with E7015 in the
interpreter's words.

## Governance

- The loader itself does not allocate scratch storage: names and messages are built in bounded stack buffers,
  so the counted harness sees no allocation of its own.
- The loader's own reason is never appended. The interpreter reads it after the
  loader has already handed it to an inner attempt, so its message carries none.
- The loader holds a reference to `pow`, so a linker that drops unused libraries
  keeps the math library, and `c` reaches the math functions as the interpreter's
  process does (Linux CI found `pow` and `sqrt` missing without it).
- `foreignLoaderMarker` tells [[Backend Toolchain]] to link the dynamic loader
  where the platform keeps it apart from the C library.

## Text and bytes (#851)

`host_foreign_text_in` validates and copies arguments, refusing embedded noughts (E7017). `host_foreign_text_out` supplies result validation and depends on the runtime text-copy helper. Result wrappers refuse missing text (E7024) and invalid UTF-8 (E7025). `host_foreign_bytes` lends a run's storage, an empty run still passing an address as the interpreter's bridge does.

## Record text fields (#852)

`pudu_foreign_missing_field` reports E7024 with the missing field name. Wrappers validate every raw text leaf before allocating field copies.

## Handle claims (#853)

The native run gate serializes calls through liveness checking, dispatch and
claim settlement. Each owned address has one live claim. Counted results can
share an address and each gets a distinct generation. Borrowed handles have
no claim. Explicit release removes the exact live generation. Teardown
drains owned claims by signed address, then counted claims by generation.
`pudu_foreign_optional_handle` (#935) supplies the address for an optional handle parameter: a null
pointer for `None`, and for `Some` the address after the same liveness refusal a bare handle receives.

## Resolved Grill Log

- Resolve each destructor before the producing call, and cache its typed
  pointer so cleanup cannot fail to resolve it.
- Select argument and result text helpers independently for scalar crossings. A
  call that only takes text needs no result copy. Record pack and unpack
  helpers still select both directions when a record contains text.
- The run gate covers the whole call. Keep a separate lease table deferred
  until dispatch can release the gate or support callbacks.

## Resolved Grill Log for #877 — Post-call settlement

Capture the diagnostic in owned storage before jumping out of the crossing. The jump boundary cannot own ABI scratch locals. The caller commits writeback before replaying the report.

## Resolved Grill Log for #877 — Checked foreign bounds

Compare signedness and width-preserving counts with buffer extents before the native call. For Bytes, the compact carrier contains the extent directly.

## Resolved Grill Log for #877 — C11 array crossings

Mark raw dispatch before capturing a post-call failure. Preflight diagnostics can release run storage without triggering mutable writeback.

## Resolved Grill Log for #877 — Optional handles

Counted claims are separate transfer obligations, even in an output batch where a unique claim uses the same address.

## Resolved Grill Log for #877 — Handle leases during dispatch

Pin input generations while a callback-bearing native call yields the gate. Release waits for the final lease and wakes on reclamation.

## Resolved Grill Log for teardown order

Release unreleased claims newest claim first, by claim generation, in both the interpreter and generated C. Scope-shaped resources such as Objective-C autorelease pools must close inside out: draining an outer pool also drains every pool pushed after it. An autorelease pool is an ordinary owned handle: `fn poolPush symbol "objc_autoreleasePoolPush" () -> owned Pool by poolPop` with `fn poolPop symbol "objc_autoreleasePoolPop" (pool: Pool) -> ()`. No new syntax.

## Resolved Grill Log for Objective-C blocks

A callback parameter written `work: block Work` crosses as one pointer to a block literal, with passing mode BlockPassing and placement BlockCallback. The block is a stack block (isa `_NSConcreteStackBlock`, no copy or dispose helpers) whose last field is the registration key, and it lives for the foreign call only. A callee that keeps the block copies it with `Block_copy`; the copy carries the key, which is how escaping blocks are copied. The block's invoke receives the block first, so the callback must declare its context first; the checker refuses otherwise with E3063 ("callback X must take its context first to cross as a block"). A late invocation after unregister finds the key retired and answers the fallback.

Generated C: the runtime part `host_foreign_block` refuses non-Apple targets with `#error`. Each signature gets a `pudu_block_invoke_<key>` that forwards to the trampoline, and the call site passes a compound-literal block.

## Referenced by

[[Native Host Runtime]] · [[Backend Emit Foreign]]

## Owned output slots (#854)

Resolved Grill Log: Reserve batch claim space before dispatch. Reject duplicate or existing addresses before exposing any new boxes. Release each unambiguous fresh obligation on refusal.

## Resolved Grill Log for the portable loader

Use the shared loader and a platform mutex for cold lookups. Cache immutable symbols with atomic reads.

## Resolved Grill Log for Objective-C dispatch

Load the declared framework before resolving the Objective-C class and selector. Cache them on each emitted method crossing.

## Resolved Grill Log for Objective-C ownership

Validate and consume an idle Objective-C receiver without waiting on an invocation that may re-enter Pudu.

## Resolved Grill Log for loader metadata lifetime

Release the module lookup records at process exit while keeping native
loader references pinned for cached callbacks and final destructors.
