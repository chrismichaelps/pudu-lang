---
type: handoff
status: ACTIVE
issue: 302
tags: [handoff, packages, release, website]
---

# Init, Package, and Download Release

## Objective and ownership

Issue #302 aligns generated projects with [[architecture/PACKAGES]], proves the consumer workflow,
and carries the change through the pre-release and production download. The user explicitly directs
implementation on `dev`, so this slice does not open an implementation PR.

The implementation role was **Tooling/Release Engineer**, owning `Pudu.Cli.Init`, the CLI argument
boundary, `Pudu.Compiler.Manifest`, `test/Pudu/Cli/InitSpec.hs`, `test/scaffold.mjs`, and their
existing mirrors. The active role is **Validation**, covering focused and full gates plus fresh
external projects. The release transition
owns version and artifact checks, promotion to `main`, and the website download flow. Other work may
exist in the repository; preserve it and do not revert unrelated changes.

The complete module mirrors precede implementation. A separate review pass must inspect source/wiki
parity and behavior before integration.

## Validation evidence

- Source-root regression: roots are compared by canonical path, so a file under `src/` searches
  `src` once even through a `src = "src"` or `./src/` self dependency; `test/` searches `test, src`.
  Covered by `testSourceRootOnce` and the scaffold gate's missing-import probes.
- CLI audit: `pudu search <query> <file>...` had been shadowed by package search; paths now select
  the declaration search. `pudu help` lists the package and publication commands.
- Fresh application and library projects generated with the real CLI check, run, test, format,
  lint, build, install a Git dependency with a stable lock, release to a bare remote, and install
  into a consumer. A 0.1.0-style manifest checks, runs, and tests unchanged.
- `test/gates.sh` passes every gate from a clean optimized build.

## Role transition

Validation → **Release Engineer**: `release/0.1.1` carries the version, release notes, and
download-page data; its PR to `main` runs CI and the archive build before merge.

## Exact next action

Open the `release/0.1.1` PR to `main` and merge it only after CI and the release-branch archive
build pass.

## Referenced by

[[handoffs/_MOC]] · [[architecture/PACKAGES]] · [[Pudu CLI Init]]
