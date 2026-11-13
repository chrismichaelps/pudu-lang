---
type: decision
status: ACCEPTED
date: 2026-11-13
tags: [decision, language, ffi, foreign, concurrency, native]
aliases: [Foreign Callbacks and Thread Affinity, ADR-0028]
---

# ADR-0028 — Foreign callbacks and thread affinity

Accepted design, not yet implemented. The syntax below stays refused until
#876 lands parser, checker, interpreter, native and diagnostic evidence
together.

## Context

[[ADR-0018-calling-a-library-written-elsewhere]] lets Pudu call a library and
leaves two questions open: how a library calls back into Pudu, and which
thread a foreign call or a callback runs on. Event loops, sort and search
routines, completion handlers, delegates and listeners all need both. The
Objective-C (#879), JNI (#880) and Swift (#881) layers build on whatever this
decision fixes, so it fixes one shape and lowers every other form onto it.

Two runtimes must agree. The interpreter runs Pudu threads concurrently and
leaves its scheduler free while a foreign call is in progress, so a library may
re-enter it. The native runtime admits one thread at a time through its run
gate (`host_gate`), and a foreign wrapper holds the gate from liveness checks
through dispatch and claim settlement ([[Native Foreign Call Sites]]).

## Decision

### One crossing shape

**A callback crosses as a C function pointer plus one opaque context pointer.**
Every callback layer, including Objective-C blocks and JNI listeners, lowers
onto this pair. An API that offers no context pointer is bound through a small
C surface that supplies one; Pudu does not generate per-closure machine code.

The function pointer is one trampoline per declared callback type. The context
pointer carries a registration key, never the address of Pudu memory. The key
names a slot in the run's registration table and carries a generation, so a
stale or retired context is detected and refused rather than dereferenced.

### Declaring a callback type

A foreign block declares each callback type before a signature names it:

```pudu
foreign "pudu_events" {
  type Source
  callback OnTick(context, source: borrowed Source, count: Int64) -> ()
  callback Visit(context, row: Int32) -> Int32 else 1
  fn open() -> owned Source by close
  fn close(source: Source) -> ()
  fn listen(source: Source, listener: OnTick, context listener) -> Int32
  fn unlisten(source: Source) -> ()
  fn each(source: Source, visit: Visit, context visit) -> Int32
}
```

- `callback Name(...)` declares a block-local nominal type. `context` marks
  the native position of the context pointer and appears exactly once.
- Callback parameters use existing crossing types: fixed-width integers,
  `Float32`, `Float64`, `Bool`, `Str`, records by value, and `borrowed` handles
  of a type the same block declares. `Bytes`, owned or counted handles, output
  slots, and callback types are refused as callback parameters.
- A callback result is `()`, a fixed-width integer, a float, or `Bool`. A
  non-unit result must name, with `else literal`, the value the library
  receives when an invocation does not run to completion. No value is guessed.
- In a foreign function, a parameter of callback type crosses as the function
  pointer at its position. A `context name` parameter places that callback's
  context at its own native position. Each callback parameter has exactly one
  `context` partner in the same function, and neither occupies an extra Pudu
  argument. Both count toward the 32-argument limit.
- The Pudu function type of `OnTick` is `fn(Source, Int64) -> ()`. It is an
  ordinary, synchronous, non-failing function type, so a callback body cannot
  propagate a recoverable failure, cannot be `async`, and requires no
  capability. The trampoline grants nothing.

### Registration is an owned token

`OnTick(handler)` registers a Pudu function value and answers an owned
registration of type `OnTick`. Registering is safe; handing the token to a
foreign function needs `unsafe(foreign)` like every foreign call. The token
behaves as an owned handle: a call that receives it leases it for the call,
and the program keeps it.

| Operation | Outcome |
|---|---|
| `token.unregister()` outside its own invocations | Refuses new invocations, waits for every in-flight invocation on every thread, then answers `Result[(), Str]`: `Err` carries the first failure the registration retained |
| `token.unregister()` inside one of its own invocations | Refuses new invocations and returns at once without waiting. The registration is reclaimed when its last in-flight invocation returns |
| A second `unregister()` | Answers the same outcome again, as a second join of a thread does |
| Passing an unregistered token to a foreign function | Runtime refusal before dispatch, as for a released handle |
| The library invokes a retired registration | The library receives the declared `else` value or nothing for `()`. No Pudu code runs. A runtime warning is reported once per registration |
| Run teardown with live registrations | Teardown retires every registration first, waits for in-flight invocations within the existing teardown bound, then releases foreign handles. A retained failure on a registration nobody unregistered is reported as a runtime warning |
| Invocation after teardown | The library receives the declared `else` value or nothing for `()`. No Pudu code runs and nothing is reported |

The registration holds its function value until it is reclaimed. The guarantee
that no Pudu code of a registration runs after `unregister()` returns holds
for an unregister made outside that registration's invocations.

### Threads

**A callback runs on the thread that invokes it.** Pudu never moves an
invocation to another thread or queue. An API with thread affinity is served
by the platform's own dispatch, such as the main queue or a looper, bound as
ordinary foreign calls. A program that wants work done elsewhere sends from
the callback body on a `Std.Channel`.

An invocation is **nested** when it runs on a thread that is inside a foreign
call Pudu made, during that call. Every other invocation is **detached**: a
foreign thread, or a library firing later from its own loop. Both run the same
body under the same rules. They differ only in where a failure is reported.

**A foreign thread attaches for the duration of one invocation.** The
trampoline adopts the invoking thread into the registration's run, runs the
body, and detaches. An implementation may cache per-thread state between
invocations. The thread inherits no capability, task, scope or failure
boundary from anywhere.

**A native foreign call yields the run gate for its dispatch.** The wrapper
checks liveness and leases handle arguments under the gate, gives the gate up
for the native call, and takes it back before claim settlement. Every
trampoline takes the gate on entry and gives it up on exit. Handle leases are
counted, and an explicit release of a leased handle waits for the lease to end.
This matches the interpreter, which already lets other threads run during a
foreign call and waits for leases before a release. A native program may skip
the yield when no other thread can contend, which is not observable.

### Failure never unwinds through a foreign frame

Every trampoline is its own failure boundary. A panic or runtime failure in a
callback body cleans up the invocation's own resources and stops at the
trampoline. The trampoline then returns the declared `else` value, or nothing
for `()`, and the library continues normally.

The registration retains the first failure and becomes failed. Every later
invocation returns the `else` value without running Pudu code.

- **Nested failure.** When the enclosing foreign call returns, Pudu settles
  its ownership first, so every resource it produced is claimed or cleaned up.
  The call then fails at its call site with the retained panic, and the
  callback's provenance is attached as related information.
- **Detached failure.** No Pudu frame is waiting. The failure is retained on
  the registration and answered by `unregister()`, as a started thread's
  failure is answered by `join`.

Invalid UTF-8 or a null pointer arriving where a callback declares `Str` is a
failure of that invocation and follows the same rule.

### Tasks, scopes and cancellation

- An invocation is no task's child. It cannot `.await` or open a scope,
  because its function type is synchronous. It cannot leave tasks behind,
  because detached tasks do not exist.
- A registration belongs to the run, not to the scope or task that created it.
  It ends at `unregister()` or teardown, as a foreign handle does.
- Foreign dispatch through ownership settlement is already masked against
  cancellation. A nested invocation runs inside that interval. A task
  cancelled while it waits in a foreign call observes the cancellation after
  the call returns. Cancelling the library's own work is an ordinary foreign
  call the binding declares.

### Ownership of crossing values

| Value | Direction | Ownership |
|---|---|---|
| Integers, floats, `Bool`, records | argument or result | Copied |
| `Str` | argument | Copied into Pudu text before the body runs. The library's storage is not retained |
| `borrowed` handle | argument | Lent for the invocation. No claim, lease or release. Keeping it longer is the declaration's unchecked assertion, as for a borrowed result |
| Captured values | registration | Held by the registration and released when it is reclaimed. Captures are immutable, as for `Std.Concurrent.start`. Shared mutable state goes through `Std.Sync` or `Std.Channel` |

### Later layers

- **Objective-C blocks (#879).** A block is a heap block whose invoke function
  is the callback type's trampoline adapted to receive the block, and whose
  captured field holds the registration key. Its copy and dispose helpers
  count block copies independently of the registration. `unregister()`
  retires invocations, and the last dispose frees the block. Because the key
  is not an address, a block that outlives its registration is refused, not
  dangling.
- **JNI listeners (#880).** A listener is a small generated class that holds
  the registration key and declares one native method per callback type, which
  forwards to the trampoline. The JNI layer attaches the thread to the virtual
  machine before the runtime attach. A trampoline never leaves a Java
  exception pending, and a Pudu failure follows the rule above.
- **Swift (#881).** A Swift closure is reached through a C-exposed entry point
  that takes the function pointer and context, which is this shape unchanged.

## Grill Log

- **Q:** Admit context-free function pointers such as a bare `signal` handler?
  **A:** No. _Rationale:_ without a context the trampoline cannot find the
  closure. Per-closure executable code would be the only alternative.
  _Rejected:_ generated code per closure; static-only callbacks as a second
  shape.
- **Q:** Pass the address of the closure as the context? **A:** No, pass a
  generation-qualified key. _Rationale:_ a library that calls after unregister
  or after teardown would dereference freed memory. A key turns that into a
  refusal. _Rejected:_ raw closure addresses.
- **Q:** Let a foreign parameter accept a plain function and register it for the
  call? **A:** No. _Rationale:_ that is an implicit conversion at the boundary,
  and ADR-0018 converts nothing implicitly. A call-scoped helper can be a
  library function over the token. _Rejected:_ two registration forms.
- **Q:** Does `unregister()` inside its own invocation wait? **A:** No.
  _Rationale:_ waiting for itself never ends, and two invocations unregistering
  each other would deadlock. Reclaiming at the last exit keeps the context
  valid. _Rejected:_ waiting for other threads only.
- **Q:** Run callbacks on the main thread or a Pudu-owned queue? **A:** No, on
  the invoking thread. _Rationale:_ a hidden hop changes ordering, adds latency,
  and deadlocks when the caller waits for the callback. Platform dispatch
  already expresses affinity. _Rejected:_ implicit marshalling.
- **Q:** Keep the native run gate held across dispatch? **A:** No.
  _Rationale:_ a call that waits for a callback on another thread would never
  finish natively and would finish in the interpreter, an observable
  divergence. _Rejected:_ a per-declaration `blocking` marker, which leaves the
  deadlock to every binding author.
- **Q:** Make a callback panic fatal to the program? **A:** No. _Rationale:_
  nested failures can surface at the Pudu call site after the library
  finishes normally. Detached failures already have a model in thread join.
  _Rejected:_ aborting inside a foreign frame, where teardown would re-enter a
  library still on the stack.
- **Q:** Return zero to the library after a failure? **A:** Only if the
  declaration says so. _Rationale:_ for many APIs zero means "continue", which
  can loop forever. [[ADR-0019-getting-a-value-back-out-of-a-library]] already
  refuses zero as a guess. _Rejected:_ an implicit zero fallback.
- **Q:** Tie registrations to the creating scope? **A:** No. _Rationale:_
  foreign handles belong to the run, and a listener usually outlives the scope
  that installed it. _Rejected:_ scope-owned registrations.
- **Q:** Require `Send` and `Sync` of a registered function? **A:** No.
  _Rationale:_ captures are immutable, as for a started thread, and shared
  mutation already goes through synchronized library types. _Rejected:_ a
  marker bound stricter than `Std.Concurrent.start`.

## Consequences

- #876 adds the `callback` and `context` declaration forms, registration
  tokens, trampolines in both runtimes, the registration table, gate yield
  with counted native leases, and the failure crossing. It allocates the
  diagnostic codes.
- [[Native Foreign Call Sites]] changes: a native wrapper no longer holds the
  run gate during dispatch.
- APIs that split the function pointer and context across two calls, share one
  context among several callbacks, or pass byte runs to a callback stay refused.
  They are bound through a C surface until #877 adds function pointers and
  sized pointer values.

## Referenced by

[[decisions/_MOC]] · [[ADR-0018-calling-a-library-written-elsewhere]] ·
[[architecture/SEMANTICS]] · [[grammar/pudu]] ·
[[architecture/FFI-SELF-HOSTING]] · [[Foreign Callback Delivery]]
