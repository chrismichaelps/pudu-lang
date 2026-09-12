---
type: build
path: "@root/scripts/build-musl-runtime.sh"
fidelity: Active
tags: [build, runtime, musl, linux]
aliases: [Musl Runtime Builder]
---
# Musl Runtime Builder

Builds an x86-64 Pudu runtime in the pinned Alpine toolchain image, preserves Cabal state in the
repository build area, and verifies that the resulting executable does not depend on glibc. It also
writes a Lambda copy with `/var/task/ld-musl-x86_64.so.1` as its interpreter and copies that loader.
It copies the musl-built shared libraries named by runtime dependency inspection and
binds only the Lambda copy to their `/var/task` paths.

The runtime deliberately keeps musl's loader and named C dependencies dynamic so Pudu's
foreign-library and SQLite loading remain available. Lambda packaging carries the dependencies that
the runtime itself reports.

Resolved Grill Log: reject a runtime whose dependency inspection names glibc, and state the
cross-architecture emulation cost before beginning a local build. Do not claim static linkage when
the produced ELF records dynamic dependencies.
