---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/Cache.hs"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, backend, toolchain, cache]
aliases: [Backend Toolchain Cache, Toolchain Native Cache]
---

# Backend Toolchain Cache

## Purpose and interface

Reuses compiled native executables by content. A build whose generated C,
flags, C compiler and compiler identity match an earlier build copies that
executable instead of invoking the C compiler again. The cache is an
optimization only: it never changes what a build produces.

```haskell
newtype NativeKey
nativeKey :: FilePath -> [String] -> Text -> IO (Maybe NativeKey)
restoreNative :: NativeKey -> FilePath -> IO (Maybe Text)
storeNative :: NativeKey -> FilePath -> Text -> IO ()
```

The module is consulted by [[Backend Toolchain]] around the compiler
invocation. Callers see no cache type; they see the same result they would
see from a compile.

## Storage layout

- Root: from [[Cache Location]]. `PUDU_CACHE` off or empty disables the cache;
  otherwise the root is the named directory, or `XDG_CACHE_HOME` / `~/.cache`
  followed by `pudu`.
- Entries live under `native/` beneath the root.
- Each entry is two files: `<key>`, the executable, and `<key>.warnings`, the
  warnings the compile printed, as UTF-8 text.

## Key

`nativeKey` returns no key when the root is absent; nothing is hashed then.
Otherwise the key is a Blake2b-256 digest, rendered by `hexDigest`, over these
parts joined by NUL bytes, in this order:

- the compiler identity from [[Cache Location]];
- the compiler path as passed in;
- the output of the C compiler's `--version` flag, or the empty string when the
  flag exits unsuccessfully or cannot be run;
- the operating system and architecture;
- the caller's arguments, in the order given;
- the generated C.

Any change to one part yields a different key, so an entry is never reused for
a build it does not describe.

## Hit, miss and store

- Hit: the stored executable is copied to a temporary file beside the requested
  output and renamed onto it. The stored warnings are returned as the compile
  result, so the caller sees the same success payload as a fresh compile. The
  entry's modification time is then set to now.
- Miss: an entry that is absent, or whose warnings cannot be read, is a miss
  with no warnings to return. A miss is answered as nothing; the caller compiles.
- Store: the warnings are written to a temporary file in `native/` and renamed
  to `<key>.warnings`. Only after that succeeds is the executable copied to a
  temporary file and renamed to `<key>`. A lookup therefore finds an executable
  only when its warnings are already in place. Pruning runs after a store.
- Concurrency: every entry file is published by rename, and a restore copies
  to a temporary file before renaming to the output. A concurrent build never
  reads a partial entry or sees a partial output.

## Pruning

- A store counts the executables in `native/`. Names ending in `.warnings` or
  `.tmp` are not executables.
- Past 256 executables, the oldest by modification time are removed together
  with their `.warnings` sidecars, until 256 remain.
- A hit refreshes the entry's modification time, so recently used entries
  survive pruning. Pruning is not run on a hit.

## Failure policy

Every cache operation runs under one exception guard. An unreadable root, an
unwritable entry, a failed rename, a failed copy, a failed time update or a
failed prune is ignored; a store does nothing further and a restore answers
nothing, so the caller compiles. Cache failures are never reported as build
failures. A failed restore removes its temporary file and never leaves a
partial executable at the output path.

## Negative Logic (Prohibited Paths)

- No key from the Pudu sources: the generated C is what the compiler sees, so
  keying on it is both sufficient and exact.
- No size measurement on each build: the count bound avoids measuring stored
  files on every store.
- No entry published before it is complete, and no executable published before
  its warnings.
- No reuse across a changed C compiler, even when the path is the same: the
  version output is part of the key.

## Edge Cases

- A C compiler whose `--version` prints nothing or fails is keyed by path and
  platform alone. Its upgrades are not detected by the key.
- A restore that copies the executable but then fails to refresh the entry's
  time is reported as a miss, and the output that was already renamed stays in
  place. The caller compiles and overwrites it.

## Grill Log

- **Q:** Why key on the generated C rather than the Pudu sources? **A:** The C is
  what the compiler sees. Identical C with identical flags and compiler yields an
  identical executable, whatever produced the C. _Rejected:_ keying on sources,
  which misses changes in the emitter and the runtime.
- **Q:** Why include the compiler's version output? **A:** An upgraded C compiler
  must not reuse executables built by the previous one, and the path alone does
  not change on an upgrade.
- **Q:** Why bound by count? **A:** Executables are a few hundred kilobytes to a
  few megabytes. A count bound keeps the directory small without measuring sizes
  on every build.
- **Q:** Why write the warnings before the executable? **A:** A lookup that finds
  an executable must also find its warnings, so a hit never returns a success
  payload with warnings missing. _Rejected:_ writing the executable first, which
  leaves a window where a hit has no warnings to return.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Toolchain]] · [[Backend Toolchain Process]] · [[Native Build Cache Delivery]] · [[Cache Location]]
