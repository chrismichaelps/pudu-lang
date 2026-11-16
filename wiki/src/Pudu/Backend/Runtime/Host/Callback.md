---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Callback.hs"
fidelity: Active
grammar: C11
aliases: [Native Host Callbacks]
---

# Native Host Callbacks

Emit the active run's native callback registrations and foreign-call failure
scope. Typed trampolines supply their own ABI conversion and fallback.

## Resolved Grill Log

- All mutation uses the run gate. Callback contexts carry unique generations
  and equal nominal type identities.
- A registration remains pinned while a native call leases it or a
  trampoline invokes it. Retirement blocks new invocations immediately.
- A trampoline saves the interrupted frame and installs a local failure
  boundary. Nested failure is copied to the caller's scope. Detached failure
  remains on the registration.
- The protected C function uses an already pinned invocation. Lookup and
  retirement stay outside the setjmp frame so GCC sees a stable lifetime.
- Teardown closes callback admission and waits within the native foreign
  timeout before tearing down handle claims. A late trampoline uses its
  typed fallback and acquires no interpreter state.

## Referenced by

[[Backend Toolchain App]] · [[Foreign Callback Delivery]] · [[Backend Frame Runtime]]
