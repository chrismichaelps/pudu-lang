---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Http.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, http, network]
aliases: [Package Http]
---

# Package Http

## Purpose and interface

`send` makes one HTTP/1.1 request on a new connection (`Connection: close`) and reads the whole response by `Content-Length`, chunked coding, or connection end. `https` goes through `Eval.Tls` (system trust store, the host name asked for, TLS 1.2 or 1.3); plain `http` is accepted only for `localhost`, `127.0.0.1`, or `::1`. Connection, each write, and each read have `timeoutMillis` (30 s); bodies over `responseLimit` (256 MiB) and heads over 64 KiB are refused. `parseUrl` reads `http(s)://host[:port]/path`.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** An HTTP library? **A:** A small client over the existing verified TLS connection. _Rationale:_ one audited place decides certificate checks. _Rejected:_ a second TLS configuration.
- **Q:** Plain HTTP to a remote registry? **A:** Refused. _Rationale:_ tokens travel in headers. _Rejected:_ an opt-out flag.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs` and `test/package-registry.py`.
