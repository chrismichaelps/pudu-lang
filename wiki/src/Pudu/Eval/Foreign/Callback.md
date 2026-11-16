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

## Referenced by

[[Eval Call]] · [[Foreign Callback Delivery]] · [[src/Pudu/Eval/_MOC]]
