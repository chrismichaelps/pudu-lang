---
type: build
path: "@root/deploy/musl.Dockerfile"
fidelity: Active
tags: [build, runtime, musl, linux]
aliases: [Musl Toolchain Image]
---
# Musl Toolchain Image

Defines the Alpine toolchain used to build Pudu against musl with GHC 9.10.1 and Cabal 3.12.1.0.
It installs the development libraries and static archives needed by the runtime while leaving musl
as the only dynamic loader dependency.

Resolved Grill Log: build against the target libc instead of cross-linking from glibc; pin the
toolchain and Alpine generation so runtime compatibility is explicit and repeatable.
