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
| Resolved | Mutation through references | Assignment to a `mut` field, an array element, and through `*r`, `&mut` arguments handed back on every exit, `&mut self` methods, and the refusal of writes to `let` bindings and parameters are implemented ([[ADR-0022-lending-a-place]]): `UsesPlaces` evaluates 18 writes and `PlaceSpec` covers every acceptance and refusal. Measured on 2026-09-15, a `let` and a parameter had been assignable and `&mut` had changed nothing. | Ships with the first release. |
| Critical | Package and compatibility tooling | [[architecture/PACKAGES]] specifies manifests, lockfiles, cache integrity, offline resolution, and compatibility, but the CLI does not implement `lock`, `fetch`, `update`, or `publish`. | Must complete before third-party package publication; a deliberately package-free preview may ship earlier. |
| Critical | Large-input bounds evidence | File streaming is proven: `test/residency.py` runs `Std.Io.foldLines`, `countBytes`, and `Std.Csv.foldRows` at 2 MB and 20 MB and requires the same peak, with buffered `readAllLinesOf` as a control whose peak must rise by at least the extra input (measured at 10 MB and 100 MB: `foldLines` 87 → 88 MB, `countBytes` 82 → 82 MB, buffered 104 → 359 MB). `Std.Csv.foldRows` reads a file one chunk and one record at a time with the rows `parse` gives. `Std.Json.foldLines` reads JSON Lines one value at a time, and `decode` reads a document natively. `test/residency.py` holds `Std.Json.foldLines` to the same peak at ten times the input. Network, HTTP, and database readers still lack residency fixtures, and a single JSON document is still decoded whole. | Must complete for production-readiness claims on the remaining readers. |
| High | HTTP client lifecycle | Verified TLS, redirects, destination policy, response limits, and one whole-chain deadline ship. Explicit in-flight cancellation and bounded connection pooling remain absent. | Required for sustained service workloads. |
| High | Structured concurrency | Joinable workers, bounded parallel maps, channels, mutexes, and atomic cells ship. Worker ownership by lexical scopes, cancellation propagation, and cancellation points remain incomplete. | Required before calling the host-worker layer stable. |
| High | Filesystem safety surface | Streaming files and portable lexical paths ship. `Std.Fs` adds rename-based atomic replacement, temporary files and directories whose names are claimed by creating them, scoped cleanup, portable permissions, metadata, link-aware containment, and removal that never follows links; `Std.Io.copy` is byte-exact and `move` renames. Flushing data to the device before a rename is not yet exposed. | Delivered as focused APIs beside lexical `Std.Path`; device flush remains for durability across power loss. |
| High | Native application UI, audio, and video | Portable Pudu cores ship: `Std.Ui.Canvas` (exact RGBA rendering and repaint), `Std.Ui.Layout` and `Std.Ui.Screen` (placement, semantics, focus, input routing, damage), `Std.Ui.Text`, `Std.Audio` and `Std.Audio.Graph` (exact PCM, mixing, resampling, WAV), and `Std.Video` (exact timing and tracks). `Std.Ui.Desktop` presents a checked window and `Std.Audio.Device` plays a persistent default-device stream on macOS. Linux and Windows presenters and audio adapters, device selection, and the gaps named in [[Desktop Capability Conformance]] remain. | Portable cores are delivered; platform presentation beyond macOS remains before calling desktop applications portable. |
| Medium | Regular expressions | `Std.Regex` ships beside the parser combinators: `compile` answers a typed `RegexError`, and `search`, `findAll`, captures, `replaceAll`/`replaceAllWith`, `split`, and `escape` run under a step limit so a pathological pattern refuses rather than hangs. Compile-time validation of literal patterns is not implemented. | Shipped for v1; literal-pattern checking at compile time remains optional. |
| Medium | CLI application arguments | `Std.Args` declares flags, values, and required and repeated options, and parses the command line into a typed result with a typed `ArgsError`, and writes the help text; `Std.Env` keeps the basic flag and positional readers. Subcommands are not yet a declared form. | Subcommands follow a demonstrated application need. |
| Medium | Compression/archive breadth | Gzip/DEFLATE, POSIX tar, and zip (`Std.Archive.Zip`, reading and writing under an entry limit) ship with bounded decoding; zstd does not. | Add by demonstrated workload, not as a v1 completeness checklist. |

## Pre-release 0.1.0

The first release is a **package-free pre-release**, published as `v0.1.0` and marked pre-release. It
ships what the table shows as implemented and makes no claim the open rows would contradict:

- **Resource ownership and cancellation** blocks a *stable* release, which this is not. The release
  notes say that some resources rely on an explicit `close` and that cancellation does not propagate
  between workers.
- **Package tooling** admits "a deliberately package-free preview". The notes say dependencies are
  local directories and that locking, fetching, updating, and publishing are not implemented.
- **Large-input bounds** blocks *production-readiness claims*. The notes claim a flat peak only for
  the readers measured — files, CSV, and JSON Lines — and say the others are unmeasured.

Evidence at the release point: the full suite, the optimized `-Werror` build, the formatter, the
diagnostic-code, and the release-decision gates pass; every standard library module and example
checks; the 87 documentation examples run; and the [[Release Workflow]] builds the Linux and macOS
archives and runs a program from each unpacked archive outside the repository before it may publish.
Publishing happens only when the release PR is merged to `main`, and only a change to
`packages/pudu/` at an untagged version publishes ([[Release Plan]]).

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
