---
type: module
path: "@root/src/Pudu/Lsp/ModuleCatalog.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Module Catalog]
---

# LSP Module Catalog

## Purpose

List every module an import in a program could reach, for import completion: the program's own, its
manifest dependencies', and the standard library's.

## Interface

```haskell
moduleCatalog :: FilePath -> IO [Text]
modulesUnder  :: (Text -> Bool) -> FilePath -> IO [Text]
```

## Governance

- The roots are the ones [[Compiler Library]] searches, taken from one resolution context for the
  source root, so an offered module is one an import would find. Standard roots contribute only the
  `Std` namespace, matching the rule that a non-standard module is never looked for in the library.
- A module is named by its path from the root: `root/Std/Io.pudu` is `Std.Io`.
- Only directories whose names can be module segments (an ASCII capital followed by letters, digits,
  or `_`) are entered, and only such entries are examined at all. A source root that is also a
  repository root therefore never walks build output, `node_modules`, or `.git`.
- The walk reads at most a fixed number of directories, so an editor opened on a very large tree
  still answers promptly with the modules nearest its root.
- Unreadable directories are skipped rather than failing the catalog.
- [[Lsp Server]] builds a catalog once per source root and keeps it until a file is saved, created,
  deleted, or renamed.

### Linkage

- **Requires:** [[Compiler Library]], [[Syntax]].
- **Consumed by:** [[Lsp Server]].

## Negative Logic (Prohibited Paths)

- Do not descend into directories that cannot be module segments.
- Do not offer non-`Std` names found under a library root.
- Do not rebuild the catalog per completion request.

## Grill Log

- **Q:** Why walk the filesystem at all, when the program's graph already lists its modules? **A:**
  An import is written to reach a module the program does not use yet. _Rationale:_ the graph only
  knows what is already imported, which is the least useful answer at an import. _Rejected:_ offering
  only the program's current modules.
- **Q:** Why a directory budget instead of no limit? **A:** An editor may be opened on a home
  directory. _Rationale:_ completion must answer promptly; a partial catalog is still correct for
  every module it lists. _Rejected:_ an unbounded walk.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Import Completion]] · [[Lsp Server]]
