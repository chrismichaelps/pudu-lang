---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Foreign/CallbackStore.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, foreign, ffi, runtime]
aliases: [Foreign Callback Store]
---

# Foreign Callback Store

Own callback registration, invocation admission and retirement for
one interpreter run under [[Foreign Callbacks and Thread Affinity]].
The store carries opaque registration keys and retained failures. The
trampoline adapter supplies the handler invocation and converts boundary
failures before returning over the C stack.

## Resolved Grill Log

- **Q:** Can a stale key reach a different handler? **A:** Each store
  issues nonzero pointer-width generations once and refuses exhaustion.
  The trampoline selects the owning run before looking up its key.
- **Q:** What keeps a handler live? **A:** Dispatch takes atomic leases
  for all its tokens. Invocation separately pins the handler. Retirement
  prevents new entries immediately and releases the handler after its
  final invocation and lease. A tombstone answers subsequent operations.
- **Q:** How does unregister detect its own invocation? **A:** The
  interpreter supplies the keys in the current callback ancestry. The
  store waits only for unregister outside those invocations.
- **Q:** Where does a callback failure go? **A:** The first failure stays
  with the registration. An invocation result carries it back to the
  adapter for nested-call propagation. Unregister returns the retained
  failure. Closing the store returns undelivered failures to teardown.
- **Q:** Is late invocation possible after teardown? **A:** The closed
  store refuses before lookup and without warning. The bridge owns the
  function pointer and must preserve that fallback path independently
  of the run's captures.

## Referenced by

[[src/Pudu/Foreign/_MOC]] · [[Eval Runtime]] · [[Eval Env]] · [[Foreign Callback Delivery]]
