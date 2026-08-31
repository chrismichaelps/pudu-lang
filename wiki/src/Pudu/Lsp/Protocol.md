---
type: module
path: "@root/src/Pudu/Lsp/Protocol.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Protocol]
---

# Lsp Protocol

## Purpose

Frame messages on the wire and name the shapes they carry.

## Interface

The exported signatures are the module header's export list.

### Governance

- Framing is checked on **raw bytes** by `test/lsp-session.mjs`. A harness that reads the stream as text with universal newlines silently rewrites CRLF to LF and then reports a protocol violation that is its own — which is exactly what happened the first time this was tested.

- **Everything is bytes.** `Content-Length` counts UTF-8 bytes, and reading that many *characters* would desynchronise the stream the first time a client sent a non-ASCII identifier — after which every later message is read from the wrong offset.
- A request and a notification are separated at the point of decoding rather than checked later, because replying to a notification is the one protocol error a client cannot recover from.
- Only `Content-Length` is acted on. An unknown header is skipped rather than refused, so a newer client can still talk to an older server.
- A client that sends a bare LF instead of CRLF is understood rather than hung up on.
- A `Position` is a zero-based line and a **UTF-16** offset within it, which is what the protocol specifies and what an editor's cursor reports.
- Reading a frame answers **which of four things happened**, not whether it worked: the stream ended, the frame was not addressed to the server, the frame could not be read, or a message arrived. Only the first ends a session, and collapsing them into one absent value is what let a single unreadable frame stop the server.
- A message with no `method` is a **client's reply** to something the server asked. It is ordinary traffic and is told apart from a frame that could not be read at all, because a server that grows one request to the client would otherwise be killed by the answer.
- A body shorter than its `Content-Length` is a frame the client never finished. Waiting for the rest of it never returns.

### Linkage

- **Requires:** [[Source Text]], [[Diagnostic Model]].
- **Consumed by:** [[Language Server]].

## Algorithm

Direct structural recursion over the shape being read or written; no caching and no mutation.

Reading is framing first and content second, and the two fail differently. A body that was not JSON was still exactly `Content-Length` bytes long, so the reader is still aligned on the next frame and reading can continue. A frame with no length, or one that stopped short, leaves the reader somewhere in the middle of the stream, and the protocol carries no marker to find the next boundary by — so that is where a session ends.

## Negative Logic (Prohibited Paths)

- No compilation, no analysis, and no decision about what a program means.
- No acceptance of input the format does not admit.
- No reporting of an unreadable frame as the stream ending, which stops a session that could have carried on.
- No attempt to resynchronise after a framing fault, since there is no marker to resynchronise on and every later read would be guesswork.

## Edge Cases

- A frame with `id` and `result`, or `id` and `error`, and no `method` is a client's reply and is passed over.
- A frame whose body is not JSON, or whose JSON has no `method`, costs that frame and nothing more.
- A frame with no readable `Content-Length`, or a body shorter than the length it declares, ends the session.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Language Server]] · [[Tooling]]
