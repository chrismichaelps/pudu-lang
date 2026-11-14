---
type: handoff
status: ACTIVE
issue: 876
aliases: [Foreign Callback Delivery]
---

# Foreign Callback Delivery

Language Architect → Frontend, Semantic, Runtime and Backend Engineers.
[[Foreign Callbacks and Thread Affinity|ADR-0028]] is the contract. #876
implements it in the parser, checker, interpreter bridge and native runtime.

## Resolved Grill Log

- One crossing: a function pointer per callback type plus a context key from
  a generation-qualified registration table. A raw closure address never
  crosses.
- `callback Name(...)` and `context name` stay contextual words. A non-unit
  callback result requires `else literal`.
- `Name(f)` answers an owned registration. `unregister()` answers
  `Result[(), Str]`, waits outside its own invocations, and returns at once
  inside them.
- The native wrapper yields the run gate for dispatch. Handle arguments move to
  counted leases, and an explicit release waits for them, as in the interpreter.
- Every trampoline is a failure boundary. Nested failures fail the enclosing
  call after settlement. Detached failures are retained for `unregister()`.
- Teardown retires registrations before releasing handles. Invocations after
  teardown return the `else` value and run no Pudu code.

## Validation required

Sort and search callbacks invoked during the call, and a registered listener
fired from the main thread and from a foreign thread. Refusals for an
unregistered token, a retired invocation, and an invocation after teardown.
Nested and detached failures. Unregister inside an invocation. Identical
interpreter and native output, counted cleanup, and sanitizer runs.

## Exact next action

Write the mirrored `wiki/src/` pages with resolved Grill Logs for the parser,
checker and interpreter bridge modules #876 touches, starting with the
`callback` and `context` declaration forms.

## Referenced by

[[handoffs/_MOC]] · [[Foreign Callbacks and Thread Affinity]]
