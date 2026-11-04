---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Lsp/ModuleCatalog.hs"
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

- The roots are the distinct union of ordinary and shipped search roots from one
  [[Compiler Library]] resolution context. For each root, admit a first namespace segment only
  when the compiler's search roots for that segment include this root. This shared policy includes
  every shipped namespace and excludes package-owned shipped names automatically.
- Never subtract root-list lengths: ordinary lookup contains package roots that shipped lookup
  excludes, so positional subtraction can discard the real library.
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
- Do not offer any namespace from a root the compiler would not search for that namespace.
- Do not rebuild the catalog per completion request.

## Grill Log

- **Q:** Hardcode the shipped namespace set again in completion? **A:** No; query compiler
  policy for each first segment. _Resolved:_ project overrides, package exclusion and future
  shipped namespaces all follow the same resolution decision.
- **Q:** Assume ordinary and shipped root lists share a prefix of the same length? **A:** No;
  enumerate their distinct union and filter by membership, retaining bounded per-root traversal.

- **Q:** Why walk the filesystem at all, when the program's graph already lists its modules? **A:**
  An import is written to reach a module the program does not use yet. _Rationale:_ the graph only
  knows what is already imported, which is the least useful answer at an import. _Rejected:_ offering
  only the program's current modules.
- **Q:** Why a directory budget instead of no limit? **A:** An editor may be opened on a home
  directory. _Rationale:_ completion must answer promptly; a partial catalog is still correct for
  every module it lists. _Rejected:_ an unbounded walk.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Import Completion]] · [[Lsp Server]]
