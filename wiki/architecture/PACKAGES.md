---
type: architecture
status: ACTIVE
tags: [architecture, packages, tooling]
aliases: [Package System]
---

# Package System

## Purpose

Make a Pudu project reproducible from a small manifest and an immutable lockfile without allowing a
dependency to execute installation code or replace the shipped standard library.

## Project Layout

`pudu.toml` marks the project root. Source defaults to `src/`; tests default to `test/`; both may be
changed to relative paths that remain inside the project.

```toml
[package]
name = "acme-report"
version = "1.2.0"
language = ">=0.6.0, <0.7.0"
source = "src"

[dependencies]
acme-data = "^2.1.0"

[dev-dependencies]
acme-fixtures = { path = "../fixtures" }
```

Package names use lowercase ASCII letters, digits, and single hyphens. Published packages own the
matching PascalCase root module (`acme-data` owns `AcmeData.*`); `Std` and `Core` are reserved. This
keeps the existing absolute import grammar and canonical module identities unambiguous. A resolved
graph containing two packages that claim one module is rejected before compilation.

## Dependency Sources

- **Registry:** a semantic-version requirement resolved against a configured HTTPS registry.
- **Path:** a local project used directly during development; its normalized path and manifest
  digest are locked, but it is not publishable as a transitive registry dependency.
- Git dependencies are not in the first stable surface. A mutable branch or tag is not an immutable
  package source, and a commit-only source still needs archive/checksum/security rules already
  provided by the registry.

The solver selects one version per package name for the whole graph. This matches Pudu's current
module and nominal identity model and makes diamond dependencies explicit. An unsatisfiable graph
reports the shortest conflicting requirement chain; it never silently installs two identities with
the same source name.

## Lockfile

`pudu.lock` is generated, deterministic, and committed for applications. Entries sort by package
name and contain exact version, source registry, archive SHA-256, manifest SHA-256, and exact
dependency names/versions. Libraries may omit a lockfile from publication; CI and release commands
require `--locked` for applications.

Resolution writes a temporary complete lockfile and atomically replaces the old one only after every
entry validates. Failure leaves the previous lock untouched. `--frozen` forbids network access and
any lockfile change; `--offline` permits the local cache but no network.

## Registry and Cache Protocol

The client reads a version index and immutable package archives over verified HTTPS. Every response
has a byte limit and deadline. The index provides archive URL, SHA-256, size, language range, and
dependency requirements. Archives contain source, `pudu.toml`, README, license, and optional docs;
they contain no executable install hooks.

Downloads stream to a temporary file while hashing, reject a size mismatch or checksum mismatch,
then move into a content-addressed cache. Extraction rejects absolute paths, `..`, device files,
links escaping the destination, duplicate paths, and configured expanded-size/file-count limits.
Published `(name, version)` records are immutable.

## Commands

- `pudu init [path]` creates a manifest and source skeleton without overwriting files.
- `pudu lock` resolves and atomically updates `pudu.lock`.
- `pudu fetch [--locked|--frozen|--offline]` fills the cache without compiling.
- `pudu check|run|test|build` discover the manifest, require the selected lock policy, and compile
  the package graph in dependency order.
- `pudu publish --dry-run` builds the exact archive and validates namespace, docs, license, tests,
  ignored/private files, and size before any upload. Upload requires an explicit later registry
  credential flow and never reads credentials into the manifest or lockfile.

## Compatibility

The manifest's `language` range is checked before parsing package source. Public package versions use
Semantic Versioning 2.0.0. The tool cannot prove API compatibility yet, so `pudu publish` reports the
previous version and requires the author to select the correct version; future interface-diff tooling
may make that check mechanical.

The shipped `Std.*` tree is always resolved from the compiler distribution after a project-local
intentional shadow and before packages. Dependencies may not publish `Std.*` or `Core.*` modules.

## Diagnostics

Package/tool failures use `E7xxx` and retain a causal chain: manifest location, package requirement,
selected source, and underlying network/filesystem cause. Resolver order is deterministic so the
same graph reports the same primary conflict.

## Production Gates

- Manifest TOML success/failure/diagnostic fixtures.
- SemVer precedence and requirement property tests.
- Resolver diamonds, conflicts, cycles, yanked versions, offline cache hits/misses, and deterministic
  lockfile snapshots.
- Archive traversal/link/bomb/checksum tests and atomic-failure tests.
- A local registry conformance server; public network tests are never required for the normal suite.
- Repeated clean/locked/offline builds produce equivalent module graphs and artifacts.

## Grill Log

- **Q:** Allow arbitrary install/build scripts? **A:** No. _Rationale:_ they execute dependency code
  before the project is built and turn resolution into remote code execution. _Rejected:_ npm-style
  lifecycle hooks.
- **Q:** Resolve several versions of one package simultaneously? **A:** Not in the first stable
  system. _Rationale:_ current module/nominal identity has no package qualifier; pretending otherwise
  aliases distinct public types. _Rejected:_ basename deduplication; whichever version resolves first.
- **Q:** Trust TLS without checksums? **A:** No. _Rationale:_ TLS authenticates transport endpoints;
  the lockfile authenticates the immutable content selected for this graph. _Rejected:_ mutable tag
  URLs; checksum stored only in the cache.
- **Q:** Let a package replace `Std`? **A:** No. _Rationale:_ the standard library is versioned with
  the compiler and is part of the language distribution. _Rejected:_ dependency precedence over
  distribution modules.

## Referenced by

[[architecture/_MOC]] · [[Engineering Delivery]] · [[Compiler Program]] · [[Compiler Library]] · [[Pudu CLI]]
