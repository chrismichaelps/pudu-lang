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

## Parser partition

Language Architect → Frontend Engineer owns the foreign declaration parser,
foreign syntax, cached spans, and stores. Semantic Engineer owns the
declaration admission boundary. The #935 worktree now retains callback
signatures, fallback literals, and native context positions. Checked
programs still refuse these forms before either runtime can dispatch them.

## Signature partition

Frontend Engineer → Semantic Engineer owns [[Foreign Callback Signature]]
and its use in [[Type Check Foreign]]. The signature validator records the
trampoline's native parameter order and typed fallback. Pairing records the
function and context positions and rejects forward, missing, unmatched and
ambiguous references. The checker continues to refuse runtime admission.

## Nominal bindings

Semantic Engineer owns the callback token shell, namespace and import
projection, and checked registration function. `Name(f)` takes a synchronous
function and returns the token from its declaring module. A checked foreign
signature uses the token as its Pudu argument and omits the native context slot.

## Interpreter registration store

Semantic Engineer → Runtime Engineer owns [[Foreign Callback Store]],
[[Eval Env]] and [[Eval Runtime]]. The store now admits calls through atomic
leases, pins handlers during invocation, retains the first failure, and
supports self-unregister and bounded teardown. The interpreter closes it
before releasing foreign resources.

## Interpreter registration values

Runtime Engineer owns callback registration, token and unregister values,
and the installation of checked callback/context metadata in
[[Eval Foreign Binding]]. The evaluator retains the handler in the run's
store and projects unregister to a Pudu Result. The foreign dispatch guard
remains until the trampoline can safely enter the evaluator.

## Native trampoline bridge for the interpreter

Runtime Engineer owns [[Pudu FFI Callback Bridge]] and [[Foreign Callback Native Adapter]]. The C bridge caches executable ABI adapters and gives each
live context a nonreused native generation. It drops the interpreter stable
pointer after retirement and the last in-flight invocation. The adapter
retains only its checked ABI and fallback after that. Outbound calls carry
their scope through the native thread for nested failure routing.

## Interpreter dispatch

Runtime Engineer owns the argument weaving, scoped libffi call, evaluator
invocation, callback leases and native context retirement. Nested failures
are delivered after foreign ownership settlement while detached failures
stay with the registration. The checked-source admission guard remains until
C11 lowering and dispatch implement the same crossing.

## Native lowering

Runtime Engineer → Backend Engineer owns callback lowering, core signatures,
foreign ABI slots and frame carriers. Direct and retained operations lower
to the same native frame operation. Foreign calls carry the full checked
pointer/context positions without adding a Pudu argument for context.

## Exact next action

Emit the native callback registration store and typed C11 trampolines, then
consume the pointer/context slots in foreign wrappers and hand the run gate
back around native dispatch.

## Referenced by

[[handoffs/_MOC]] · [[Foreign Callbacks and Thread Affinity]]
