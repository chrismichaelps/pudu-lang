---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Manifest.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Compiler]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.56
depth_status: DEEP
coupling: 2.0
interface_stability: 0.78
tags: [module, deep]
aliases: [Compiler Manifest]
---

# Compiler Manifest

## Purpose

Read the one project manifest governing a source root and turn it into an immutable resolution
snapshot whose dependencies and language diagnostics agree about the exact bytes read.

## Interface

### Signatures

```haskell
data Manifest
data Dependency
data ManifestSnapshot
data ManifestMetrics

readManifestSnapshot :: FilePath -> IO ManifestSnapshot
manifestSnapshotSearchRoots :: ManifestSnapshot -> [FilePath]
manifestSnapshotDiagnostics :: ManifestSnapshot -> [Diagnostic]
manifestSnapshotMetrics :: ManifestSnapshot -> ManifestMetrics

readManifest :: FilePath -> IO Manifest
findManifestRoot :: FilePath -> IO (Maybe FilePath)
manifestSearchRoots :: FilePath -> Manifest -> IO [FilePath]
projectSearchRoots :: FilePath -> IO [FilePath]
manifestVersionDiagnostics :: FilePath -> IO [Diagnostic]
```

### Governance

- A snapshot walks upward at most six directories, reads at most one `pudu.toml`, parses those bytes
  once, resolves dependency paths against that manifest's directory, deduplicates them in declaration
  order, and probes each unique dependency root once.
- `package.language` validation uses the parsed manifest and retained contents from the same snapshot.
  It never rediscovers or rereads the manifest merely to produce `E2090`.
- A missing manifest is valid and produces an empty snapshot. An unreadable discovered manifest
  retains its path and produces the existing structured diagnostic.
- Snapshot metrics count ancestor manifest checks, manifest reads, and dependency-root existence
  probes. Counts belong to the value and require no mutable global instrumentation.
- Compatibility entry points remain available; each creates or reads its own fresh state. The program
  compiler consumes one snapshot through [[Compiler Library]].

### Linkage

- **Requires:** [[Diagnostic Model]], [[Source]], [[Pudu Version]].
- **Consumed by:** [[Compiler Library]], lint configuration, and manifest-focused program tests.

## Algorithm

Normalize the source root, walk toward the filesystem root for at most six candidates, and stop at
the first `pudu.toml`. Read that file once, retaining both its path and contents, parse recognized
package and dependency keys, resolve dependency paths, remove duplicates without reordering, and
probe unique paths. Derive compatibility results and language diagnostics from the retained value.

## Negative Logic (Prohibited Paths)

- No network, registry, lock file, recursive dependency-manifest reading, or process-global cache.
- No second read for version diagnostics and no repeated dependency probe within a snapshot.
- No sorting of dependency roots: declaration order is semantic resolution precedence.

## Edge Cases

- No manifest means zero reads, zero dependency probes, and no diagnostics.
- A manifest may be created, removed, or changed between compiler invocations; a later snapshot sees
  the new state.
- Repeated dependency paths keep their first position and incur one existence probe.
- An invalid or incompatible language constraint reports against the retained manifest contents.

## Depth

DEPTH 0.56 (DEEP). The module owns bounded project discovery, byte-consistent parsing and
diagnostics, ordered dependency-root resolution, and deterministic measurement of setup work.

## Grill Log

- **Q:** Should version validation call `readManifest` after dependency discovery? **A:** No.
  _Rationale:_ two reads can observe different files and double startup IO. One snapshot makes the
  diagnostic and search graph coherent. _Rejected:_ independent convenience calls in the graph walk.
- **Q:** Should dependency manifests be followed recursively? **A:** No. _Rationale:_ the declared
  path is a module root; recursive manifests would introduce package resolution semantics absent
  from the language contract. _Rejected:_ transitive manifest traversal; implicit package manager.
- **Q:** Should snapshots persist between commands? **A:** No. _Rationale:_ independent invocations
  must observe environment and filesystem changes without timestamps or invalidation. _Rejected:_
  global cache; mtime cache; watch-service dependency.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Library]] · [[Compiler Program]]

## Dependency sources and installed packages

A dependency is a `DependencySource`: a path (bare string or `{ path = … }`), a repository
(`{ git = …, rev|tag|branch = … }`), a registry requirement under a `@handle/name` key, or an
unreadable value kept with its reason and line so `pudu install` can point at it. The package section
also yields `version`, `root`, `description`, `license`, and `keywords`.

The snapshot reads `pudu.lock` beside the manifest and adds each locked package's source directory in
`deps/` as a package root, kept apart from the project's own roots. It fetches nothing and digests
nothing; a lock it cannot read is `E7201`, and a locked package missing from `deps/` is `E7202` telling
the reader to run `pudu install`. See [[architecture/PACKAGES]].
