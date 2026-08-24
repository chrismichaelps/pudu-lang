---
type: module
path: "@root/src/Pudu/Compiler/Library.hs"
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
isStandardModule :: ModuleName -> Bool
libraryRoots :: IO [FilePath]
searchRoots :: FilePath -> ModuleName -> IO [FilePath]
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
- A checkout's `lib/` is a search root, so the compiler under development uses the standard library
  under development. Without it every change to `Std` would need an install step before it could be
  tested.

### Linkage

- **Requires:** [[Syntax Name]].
- **Consumed by:** [[Compiler Program]].

## Algorithm

Prepend the program's source root to the library roots when the module's first segment is `Std`;
otherwise return the program's source root alone. Roots that do not exist are dropped, so a search
never reports a failure against a directory that was never there.

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

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Program]] · [[architecture/STDLIB]]
