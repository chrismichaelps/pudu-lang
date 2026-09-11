---
type: build
path: "@root/scripts/build-musl-runtime.sh"
fidelity: Active
tags: [build, runtime, musl, linux]
aliases: [Musl Runtime Builder]
---
# Musl Runtime Builder

Builds an x86-64 Pudu runtime in the pinned Alpine toolchain image, preserves Cabal state in the
repository build area, and verifies that the resulting executable does not depend on glibc.

The runtime deliberately keeps musl's loader dynamic so Pudu's foreign-library and SQLite loading
remain available. All other named C dependencies are linked from static archives.

Resolved Grill Log: reject a runtime whose dependency inspection names glibc, and state the
cross-architecture emulation cost before beginning a local build.
