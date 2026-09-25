---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Progress.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, progress]
aliases: [Package Progress]
---

# Package Progress

## Purpose and interface

`Event` names what installing starts and finishes: `FetchStarted`/`FetchFinished` for a repository fetched over the network, `CacheHit` when the cache answered, `CheckoutStarted`, `Resolved` with the package count, `CopyStarted`/`CopyFinished` for a package written into `deps/`, and `UpToDate` for one that already matched the lock. `Progress` is a function accepting events, possibly from several threads at once; `silentProgress` drops them.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Let the installer print? **A:** No; it emits events. _Rationale:_ a terminal, a CI log, and a test want different output from the same work. _Rejected:_ printing inside `Package.Install`.
- **Q:** Strings or typed events? **A:** Typed. _Rationale:_ a front end counts them (fetched, from cache, copied, up to date) without parsing text. _Rejected:_ free-form messages.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
