---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Library.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Compiler]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.7
tags: [module, shallow]
aliases: [Compiler Library]
---

# Compiler Library

## Purpose

Decide where a module is looked for: the program's own tree, and — for a `Std` module — the
standard library shipped with the compiler.

## Interface

### Signatures

```haskell
data ResolutionContext
data ResolutionMetrics

newResolutionContext :: FilePath -> IO ResolutionContext
resolutionDiagnostics :: ResolutionContext -> [Diagnostic]
resolutionSearchRoots :: ResolutionContext -> ModuleName -> [FilePath]
resolutionTriedRoots :: ResolutionContext -> ModuleName -> [Text]
resolutionMetrics :: ResolutionContext -> ResolutionMetrics

isStandardModule :: ModuleName -> Bool
candidateRoots :: IO [FilePath]
libraryRoots :: IO [FilePath]
searchRoots :: FilePath -> ModuleName -> IO [FilePath]
triedRoots :: FilePath -> ModuleName -> IO [FilePath]
```

### Governance

- Membership in the standard library is by **namespace**, not by a list of names: `Std.Http.Server`
  must be a standard module the day it is written, without this module learning about it.
- The program's own source root is searched first, so a program may shadow a standard module —
  deliberately and visibly, since the shadowing file is in the program's own tree where a reader
  will find it.
- A **non-standard** module is never looked for outside the program. A typo in an ordinary import
  must be reported as a missing module in the program, not resolved against a library the author
  did not mean.
- There is no network step, no cache, and no version resolution. A Pudu program's dependencies are
  its own files plus the compiler it is built with, and that is the whole answer.
- Library roots query `PUDU_LIB`, Cabal installed data files (`Package.getDataFileName "lib"`),
  versioned package development paths (`packages/pudu/v<major>.<minor>/lib`), and root `lib/`.
  The compiler under development uses the local standard library without an extra install step.
- `newResolutionContext` performs every environment, executable, current-directory, manifest, and
  root-existence query once for one compile invocation. Candidate roots are deduplicated before
  existence probes while preserving first-match precedence.
- `ResolutionMetrics` reports manifest ancestor checks, manifest reads, executable ancestors, and
  root existence probes. It is deterministic evidence about setup work, not a process-global
  telemetry sink.
- Existing IO entry points remain compatibility conveniences. Program compilation uses the pure
  context accessors so module count cannot multiply setup discovery.

### Linkage

- **Requires:** [[Syntax Name]].
- **Consumed by:** [[Compiler Program]].

## Algorithm

Load one [[Compiler Manifest]] snapshot, collect the standard-library candidate descriptions, remove
duplicate filesystem paths in first-seen order, and probe each unique root once. Store the program
root, existing dependency roots, existing library roots, attempted-root descriptions, manifest
diagnostics, and operation counts in `ResolutionContext`.

Prepend the program's source root and manifest dependency roots to the library roots when a module's
first segment is `Std`; otherwise return only project-owned roots. These per-module queries are pure.

Reporting a module that was not found is written for a reader by `triedRoots`. When a library root
exists it names the program's roots and the library roots found, because the module is most likely
misspelled. When none exists, the search alone names nothing, so it names the locations that were
empty instead: `PUDU_LIB` when set, the installed `lib/pudu` beside the executable's `bin`, the
package data directory, and the walk up from the executable described once — "that directory and
every directory above it" — rather than spelled out for each ancestor, which ran to some forty
paths.

## Negative Logic (Prohibited Paths)

- No network access, no download, no cache directory, and no lock file.
- No version selection: there is one standard library, and it is the compiler's.
- No fallback for an ordinary module, which would let a misspelled import resolve to a library
  module by accident.

## Edge Cases

- `PUDU_LIB` overrides the search when a distribution is installed somewhere unusual; it is a path,
  not a list, because a second library root is a package manager in disguise.
- The executable's own directory is consulted through `getExecutablePath`, which can fail on a
  platform that does not support it; the failure drops that root rather than the whole search.
- Duplicate roots reached through `PUDU_LIB`, installation layout, package data, or checkout layout
  retain their earliest precedence and incur one existence probe.
- No context is reused across invocations. A new `PUDU_LIB`, newly created root, or changed manifest
  is therefore visible without invalidation machinery.

## Depth

DEPTH 0.30 (SHALLOW by intent). It answers one question about paths.

## Grill Log

- **Q:** Should `Std` resolve *before* the program's own tree, so a standard module cannot be
  shadowed? **A:** No. _Rationale:_ a program that declares `Std.Math` in its own source root has
  said something unambiguous, and a compiler that ignored it would be silently disagreeing with a
  file the author wrote. Shadowing is visible in the program's tree, which is the property that
  makes it safe. _Rejected:_ library-first resolution; a diagnostic for shadowing, which would
  punish a deliberate and legible act.
- **Q:** Should the library root be discovered from a manifest instead? **A:** Not while there is
  no package manager. _Rationale:_ a manifest that names one root is a longer spelling of the
  environment variable; a manifest that names several is the first half of dependency resolution.
  _Deferred:_ revisit with [[architecture/STDLIB]]'s deferred registry.
- **Q:** Should roots be lazily discovered the first time a `Std` import appears? **A:** No.
  _Rationale:_ one eager bounded setup makes counts deterministic, keeps missing diagnostics based
  on the same snapshot, and avoids mutable state in the graph walk. _Rejected:_ per-namespace lazy
  IO; an `IORef` cache; process-global roots.
- **Q:** Should duplicate candidates be removed after probing? **A:** No. _Rationale:_ aliases are
  otherwise paid for repeatedly even though only the first can affect precedence. _Rejected:_
  probe-then-deduplicate; sorting, which changes resolution order.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Program]] · [[Compiler Manifest]] · [[architecture/STDLIB]]
