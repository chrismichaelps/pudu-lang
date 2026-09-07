---
type: module
path: "@root/lib/Std/Http/Server/Stream.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, http, server, streaming, chunked, network]
aliases: [Std Http Server Stream]
---

# Std Http Server Stream

## Purpose and interface

Streaming HTTP/1.1 response transport using `Transfer-Encoding: chunked`. Operates directly over raw network connections (`Std.Net.Connection`) without materializing the full response body in memory, unblocking early flush of document heads and progressive delivery of asynchronous suspense components.

Exports:
- `sendHead(connection: &Net.Connection, status: Int, headers: &Array[(Str, Str)], millis: Int) -> Result[(), Net.NetError]`: Emits HTTP status and response headers immediately over the wire, setting `Transfer-Encoding: chunked` and unblocking the client parser.
- `sendChunk(connection: &Net.Connection, chunk: &Bytes, millis: Int) -> Result[(), Net.NetError]`: Frames a byte sequence as `<hex-length>\r\n<chunk>\r\n` and sends it within the stated deadline. Empty chunks are skipped.
- `finishChunked(connection: &Net.Connection, millis: Int) -> Result[(), Net.NetError]`: Emits the standard HTTP/1.1 chunked terminator `0\r\n\r\n`.
- `streamChunks(connection: &Net.Connection, status: Int, headers: &Array[(Str, Str)], chunks: &Array[Bytes], millis: Int) -> Result[(), Net.NetError]`: Coordinates complete streaming response delivery from headers to terminating frame.

## Complexity and limits

$O(1)$ memory per chunk frame: each chunk is transmitted over `Net.sendWithin` directly without buffering previous or subsequent chunks. Wire framing overhead is limited to the hex length prefix and CRLF delimiters. Connection timeouts are enforced per frame write via `millis`. HTTP/2 and HTTP/3 multiplexing are deferred to future native transports; this module targets standard HTTP/1.1 chunked wire encoding.

## Grill Log

- **Q:** Why stream directly over `Net.Connection` instead of returning a lazy sequence in `Http.Response`? **A:** Direct transport allows immediate flush of the initial TCP packet (`<head>` and critical CSS) before slow asynchronous data sources (database, external APIs) finish resolving.
- **Q:** What happens if a worker fails mid-stream? **A:** The socket is closed without writing `0\r\n\r\n`, signaling an explicit transport error to the client browser rather than a silently truncated document.
- **Q:** How are header line breaks validated? **A:** Header names and values are checked against CRLF injection before the status line is dispatched.

## Dependencies and consumers

- [[Std Net]] supplies socket transport (`sendWithin`, `NetError`).
- [[Std Bytes]] supplies raw byte slice handling.
- [[Std Html Buffer]] supplies bitwise chunk framing.
- Consumed by enterprise SSR entrypoints and streaming endpoints.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
