---
type: module
path: "@root/lib/Std/Desktop/Ipc.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, ipc]
aliases: [Std Desktop Ipc]
---

# Std Desktop Ipc

## Purpose and interface

Typed calls between the frontend and the program. `command(name, handler)` makes a `Command` from a
handler `fn(A, &Call) -> Result[R, Failure]` whose argument decodes from JSON and whose result
encodes to it; `rawCommand` takes and answers `Bytes`; `query` takes no arguments; `streamCommand` also receives a `Stream[M]` it `post`s messages to. `event[T](name)` declares an event the program
emits. `registry(commands, events)` validates them; `dispatch` answers one bridge request;
`emit`/`emitTo` build the records that deliver an event; `post` and `finish` drive a `Stream[M]`;
`typescript(registry)` writes the frontend module.

## Semantics

- Dispatch order: `OPTIONS` answers the cross-origin preflight; any other method than `POST` is
  `405`; a missing or wrong invoke key is `denied`; an unregistered name is `unknown-command`
  (`404`); a capability refusal is `denied` (`403`); a body that is not UTF-8 JSON, or that does not
  decode, is `invalid-arguments` (`400`) with the decoding path such as `.items[2].name`; a handler's
  own `Failure` keeps its kind (`failed` is `422`, `internal` is `500`).
- Every call carries `Pudu-Origin`, the origin of the document its bridge was injected into;
  `callOrigin` refuses a call whose origin is not the view's current page, so a call still in flight
  when the view navigates is never credited to the next page's origin.
- Every failure answers the envelope `{ kind, message, command, path }`; the bridge rethrows it as a
  `PuduError`.
- A request from an origin other than the application's own receives
  `Access-Control-Allow-Origin` naming that origin, so a development server can call the program;
  whether it may call a command is still the capabilities' decision.
- `registry` refuses duplicate names, empty names, and the reserved `pudu:` prefix.
- A `streamCommand` handler receives a `Stream[M]` for the channel the frontend passed in the `Pudu-Channel` header; a missing channel is `invalid-arguments`. `post` evaluates the delivery in the calling
  view; the platform runs evaluations in order, so messages arrive in the order posted.
- The generated module declares every named type once, a typed function per command (no parameter
  for a unit argument; `ArrayBuffer | ArrayBufferView` for a raw one), an `Events` map, and a typed
  `listen`.

## Grill Log

- **Q:** Should handlers be able to answer arbitrary HTTP? **A:** No. A handler answers a value or a
  `Failure`; status codes, headers and envelopes are the dispatcher's, so every command fails the same
  way and the frontend has one error type.
- **Q:** Why validate the registry instead of letting a later command replace an earlier one? **A:**
  A duplicate name is always a mistake, and a silent replacement is found only when the wrong
  handler runs.
- **Q:** Why is the decision handed to the handler? **A:** Argument scopes are about specific
  argument values only the handler can name; see [[Std Desktop Capability]].

## Dependencies and consumers

Uses [[Std Desktop Capability]], [[Std Desktop Protocol]], [[Std Desktop Shape]],
[[Std Desktop Bridge]], [[Std Desktop Webview]] and [[Std Json]]. Consumed by [[Std Desktop App]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
