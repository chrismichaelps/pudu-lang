---
type: module
path: "@root/packages/pudu/v0.1/cabal.project"
fidelity: Active
tags: [module, build, project, packaging, size]
aliases: [Pudu Package Project]
---

# Pudu Package Project

## Purpose and interface

The build plan a release uses: `scripts/build-package.py` runs the commands in `toolchain.json` from
the package directory, so this project, not the repository's [[Pudu Cabal Project]], decides how the
distributed compiler is built. It pins the same Hackage index state.

Every package, dependencies included, is built with split sections: each function gets its own
section, and linking keeps only the sections the compiler reaches. The compiler links a whole web,
database, and cryptography stack of which any one path uses little, so this and [[Package Binary]]'s
strip take the linux-amd64 executable from 58 MB to 27.8 MB (37.7 MB split but unstripped), and
the published linux-amd64 archive from 10.4 MB to 7.3 MB. The release build takes 202 s on four
cores.

## Negative logic

- Development and CI builds from the repository root are unaffected, so their dependency caches and
  build times stay as they are.
- The pinned index state changes only through an intentional dependency update.

## Grill Log

- **Q:** Enable split sections in the root project too? **A:** No. _Rationale:_ every dependency
  would rebuild in CI for a size nobody downloads. _Accepted:_ only the release plan carries it.

## Referenced by

[[Package Binary]] · [[Release Workflow]] · [[src/_MOC]]
