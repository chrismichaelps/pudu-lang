---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/Foreign/Callback.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Eval Foreign Callback]
---

# Eval Foreign Callback

Apply interpreter callback registration and unregistration values. A callback
token carries the declaring type and an opaque per-run key. Registration
retains the evaluated handler, and unregistration returns its failure as
`Result[(), Str]`.

## Resolved Grill Log

- **Q:** Does registration expose a closure address? **A:** It publishes the
  key from [[Foreign Callback Store]], which never points at the handler.
- **Q:** Does the operation require unsafe authority? **A:** Registration and
  unregistration are safe runtime effects. A foreign call retains its foreign
  capability requirement.
- **Q:** Can a callback unregister itself? **A:** The operation supplies the
  invocation ancestry in [[Eval Env]] to the store. A call outside that
  ancestry waits for the admitted invocations to finish.

## Resolved Grill Log for #876 — Callback dispatch

Lease the registrations, install ABI pointers and scope the outbound
call. Invocations use module frames and start with an independent call
depth and task scope. Same-run nested calls preserve callback ancestry
and a failure sink for the innermost foreign call.

## Resolved Grill Log for Objective-C blocks

A callback parameter written `work: block Work` crosses as one pointer to a block literal, with passing mode BlockPassing and placement BlockCallback. The block is a stack block (isa `_NSConcreteStackBlock`, no copy or dispose helpers) whose last field is the registration key, and it lives for the foreign call only. A callee that keeps the block copies it with `Block_copy`; the copy carries the key, which is how escaping blocks are copied. The block's invoke receives the block first, so the callback must declare its context first; the checker refuses otherwise with E3063 ("callback X must take its context first to cross as a block"). A late invocation after unregister finds the key retired and answers the fallback.
Interpreter: each libffi adapter lazily builds a second closure (`pudu_ffi_callback_block_code`) that reads the key from the block. `pudu_ffi_block_fill` writes the literal into storage allocated for the call.

## Referenced by

[[Eval Call]] · [[Foreign Callback Delivery]] · [[src/Pudu/Eval/_MOC]]

### Split callback placement Grill Log resolved

Adapters supply static code and registration dispatch supplies the context for the declared placement.

## Resolved Grill Log for callback byte runs

Publish a copied Bytes value to the handler.

## Resolved Grill Log for interpreter callback groups

A group entry retains the handler record. Use the native member ordinal and the admitted registration to select a field before decoding the argument leaves.
