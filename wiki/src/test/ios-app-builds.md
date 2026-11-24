---
type: module
path: "@root/test/ios-app-builds.mjs"
fidelity: Active
tags: [module, test, native, mobile, build]
aliases: [iOS App Builds]
---

# iOS App Builds

`test/ios-app-builds.mjs` builds the iOS apps that [[iOS Simulator Run]] launches. The
suite does not compile an example when its step runs; it calls `prebuild` once at start-up,
the builds run in the background, and each launch waits for its own app.

## Purpose and interface

- `prebuild(repository, compiler, library, entries)` takes the example entries, each
  `{ key, source }`, starts the builds that are not cached and returns `built(key, timeout)`.
- `built` answers the path of the `.app` once its build has left an `ok` marker. It throws
  the build log when the build leaves `failed`, and throws when the timeout passes first.
- The builds run through an `xargs` pool of up to 4 jobs, each invoked as
  `pudu build <source> --native --target ios-simulator-arm64 --app -o <app>`
  ([[Backend Toolchain App]]). The pool size is the smaller of `PUDU_IOS_BUILD_JOBS`
  (default 4) and the available cores minus one, and never below one, so one core is left for
  the simulator and the suite.
- The shell is spawned detached and unreferenced, so it outlives the step that started it.

## Cache

- The cache root is `PUDU_IOS_CACHE`, or `~/Library/Caches/pudu-ios-suite` when it is unset.
- Each entry's folder is named by the first 32 hex digits of a SHA-256 over, in order: the
  compiler binary, every file under the standard library tree, the example source, the nearest
  `pudu.toml` from the source's folder up to the repository, and every file under the
  `assets` folder beside the source. Dot-files are skipped.
- A folder holds the app, `build.log`, and either an `ok` or a `failed` marker. The waiting
  step reads the markers; it never reads the app until `ok` exists.
- A folder without `ok` is removed and rebuilt on the next run. A folder with `ok` is reused
  without any compiler call.
- The suite never clears the cache as a whole. A `jobs-<pid>.txt` file is written beside it
  for the pool and removed by the shell after the pool reads it.

## Invariants

- The key covers every input the build reads, so a cached app equals a fresh build of the same
  inputs.
- `prebuild` starts one pool per call and only for entries whose folder lacks `ok`.
- Each example key maps to exactly one folder; the same source built under two keys shares
  nothing but its key's content hash.

## Negative logic

- An unchanged example is never rebuilt: its folder holds `ok`, so `prebuild` skips it.
- A failed build reports its log: `built` throws `<key> did not build:` followed by the
  contents of `build.log`, and the suite stops that launch.
- A key that no build was started for throws `no build was started for <key>`; a launch never
  falls back to an inline build.

## Dependencies and consumers

[[iOS Simulator Run]], [[Backend Toolchain App]], [[iOS Simulator CI]]. The compiler and the
library come from the caller; the module reads no other environment variable beyond
`PUDU_IOS_CACHE` and `PUDU_IOS_BUILD_JOBS`.

## Resolved Grill Log

- **Q:** Why prebuild in parallel rather than run simulators in parallel? **A:** A Counter
  build costs about 46 s: about 24 s in the compiler, about 10 s in the program's C and about
  3 s in the iOS host. Builds are CPU-bound and independent of one another, while launches
  share one simulator, so parallel builds shorten the run and parallel simulators would not.
  _Rejected:_ several simulators, which multiply the boot cost and flake on hosted runners.
- **Q:** Why hash the compiler binary and the whole library? **A:** Any change to either can
  change every app, so the hash must cover them. Hashing is cheaper than a wrong cached app.
  _Rejected:_ modification times, which change on every checkout.
- **Q:** Why cache by content rather than by run? **A:** CI restores the cache per shard and
  per commit, so an example whose inputs did not change is not compiled again across runs.
