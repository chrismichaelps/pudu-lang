---
type: architecture
status: ACTIVE_AUDIT
tags: [architecture, release, stdlib, readiness]
aliases: [First Release Readiness]
---

# First Release Readiness

## Decision

Pudu's first serious release is a native systems-language release. A feature is a release blocker
when ordinary programs need it to build, run, fail safely, and reproduce their dependencies. Native
desktop UI, audio, and video are explicit project goals, implemented in Pudu rather than through a
foreign toolkit. Their portable cores can mature before device presentation: software rendering
produces a framebuffer, audio produces PCM streams, and video produces timestamped planes, while
each platform boundary remains named and tested.

File presence is not completion. A row is **ready** only when its public contract, typed failures,
resource lifetime, limits, focused regressions, full gate, and mirror review agree.

## Corrected priority table

| Priority | Area | Repository evidence | Release disposition |
| --- | --- | --- | --- |
| Critical | Resource ownership and cancellation | File, socket, process, worker, channel, mutex, and database boundaries exist, but several opaque resources still rely on explicit close plus evaluator teardown. Blocking host workers are not owned by lexical async scopes. | Must complete before a stable release. |
| Critical | Package and compatibility tooling | [[architecture/PACKAGES]] specifies manifests, lockfiles, cache integrity, offline resolution, and compatibility, but the CLI does not implement `lock`, `fetch`, `update`, or `publish`. | Must complete before third-party package publication; a deliberately package-free preview may ship earlier. |
| Critical | Large-input bounds evidence | File streaming is proven: `test/residency.py` runs `Std.Io.foldLines` and `countBytes` at 2 MB and 20 MB and requires the same peak, with buffered `readAllLinesOf` as a control that must grow (measured at 10 MB and 100 MB: `foldLines` 87 → 86 MB, `countBytes` 82 → 82 MB, buffered 119 → 527 MB). Network, HTTP, and database readers still lack such fixtures, and `Std.Csv`/`Std.Json` have no incremental reader at all. | Must complete for production-readiness claims on the remaining readers. |
| High | HTTP client lifecycle | Verified TLS, redirects, destination policy, response limits, and one whole-chain deadline ship. Explicit in-flight cancellation and bounded connection pooling remain absent. | Required for sustained service workloads. |
| High | Structured concurrency | Joinable workers, bounded parallel maps, channels, mutexes, and atomic cells ship. Worker ownership by lexical scopes, cancellation propagation, and cancellation points remain incomplete. | Required before calling the host-worker layer stable. |
| High | Filesystem safety surface | Streaming files and portable lexical paths ship. `Std.Fs` adds rename-based atomic replacement, temporary files and directories whose names are claimed by creating them, scoped cleanup, portable permissions, metadata, link-aware containment, and removal that never follows links; `Std.Io.copy` is byte-exact and `move` renames. Flushing data to the device before a rename is not yet exposed. | Delivered as focused APIs beside lexical `Std.Path`; device flush remains for durability across power loss. |
| High | Native application UI, audio, and video | `Std.Ui` currently means HTML/server-rendered components. No complete Pudu-native application renderer, input model, layout/accessibility tree, real-time PCM graph, rational media timeline, or platform presenter exists. | Build the portable cores entirely in Pudu with comparative correctness and latency gates; raylib and Apple publications are references, never linked dependencies. |
| Medium | Regular expressions | Parser combinators ship; regex remains deliberately deferred until literal validation versus computed-pattern failure is settled. | Useful, not a blocker for the language's v1 purpose. |
| Medium | CLI application arguments | Compiler CLI commands exist and `Std.Env` handles basic flags and positionals. Typed subcommands/help generation are absent as a standard library. | Useful application library work after critical lifecycle/tooling gaps. |
| Medium | Compression/archive breadth | Gzip/DEFLATE and POSIX tar ship with bounded decoding; zip and zstd do not. | Add by demonstrated workload, not as a v1 completeness checklist. |

## Rows from the earlier table that are no longer missing

- `Std.Process` includes started processes, stdin/stdout/stderr streaming, bounded waiting, stop,
  drain, and pipelines, plus launches with stated variables, isolation from the parent environment, a
  working directory, and `withStarted`, which stops a program when the scope that started it returns.
- `Std.Random.secureBytes` is separated from deterministic generators. `Std.Crypto` includes
  SHA-256, SHA-512, HMAC-SHA256, constant-time comparisons, password derivation, and authenticated
  encryption. SHA3-256, SHA3-512, BLAKE2b, HMAC-SHA512, constant-time byte
  comparison, and fresh key and nonce generation now ship as well; BLAKE3 is deferred until it can be
  checked against its reference vectors.
- `Std.Tls` provides verified transport with no insecure switch.
- HTTP server routing, middleware, limits, bounded connection workers, response deadlines, and a
  graceful draining deadline exist. Handler cancellation remains part of the concurrency blocker.
- Structured logging, gzip/DEFLATE, tar, JSON, CSV, and TOML exist. CBOR, MessagePack, YAML, zip,
  and zstd are optional breadth, not evidence that the existing modules are incomplete.

## Work order

1. Establish [[Native Application UI]] with a bounded Pudu-native RGBA software canvas, deterministic
   clipping, source-over blending, and exact pixel tests. Follow with measured rendering latency,
   PCM/audio, rational video time, input, layout, accessibility, and explicit platform presentation.
2. Complete filesystem safety and resource-lifetime slices.
3. Connect host workers and blocking operations to lexical scope ownership and cancellation.
4. Add HTTP client pooling and explicit cancellation after the lifetime contract is enforceable.
5. Implement package/lock/cache tooling before registry publication.
6. Add bounded-residency fixtures and run the complete release matrix.

## Grill Log

- **Q:** Treat every absent ecosystem library as a release blocker? **A:** No. _Rationale:_ native
  UI and audio are admitted because they are explicit project goals; binary serialization breadth,
  extra compression codecs, and regex do not become blockers by association. _Rejected:_ an
  unranked batteries checklist.
- **Q:** Mark a row complete because its module exists? **A:** No. _Rationale:_ public limits,
  typed failure, lifetime, regression evidence, and full validation are part of the feature.
  _Rejected:_ inventory-only readiness.
- **Q:** Bind raylib and call that the Pudu UI? **A:** No. _Rationale:_ raylib is useful evidence for
  flat frame loops, batching, clipping, and explicit device lifecycles, but the requested package is
  implemented in Pudu and is for applications rather than games. _Rejected:_ foreign toolkit
  bindings and game-shaped public vocabulary.

## Referenced by

[[architecture/_MOC]] · [[architecture/STDLIB]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
