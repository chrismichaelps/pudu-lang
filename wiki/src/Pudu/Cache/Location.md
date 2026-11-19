---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cache/Location.hs"
fidelity: Active
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
tags: [module, cache, location, identity]
aliases: [Cache Location]
---

# Cache Location

## Purpose

Name where this compiler keeps the things it reuses between runs, and name the
running compiler, so that the product cache and the native build cache agree on
both. This module is the only place that reads the cache setting and the cache
directory.

## Interface

```haskell
cacheRoot :: IO (Maybe FilePath)
compilerIdentity :: IO String
hexDigest :: Digest Blake2b_256 -> String
```

## Governance

- **Root.** `PUDU_CACHE` set to `off` or to the empty string yields no root.
  Any other value is the root directory itself. When the variable is unset, the
  root is `XDG_CACHE_HOME` when that is set and non-empty, else `~/.cache`,
  followed by `pudu`.
- **Identity.** `compilerIdentity` is a Blake2b-256 digest, rendered by
  `hexDigest`, over these fields joined by NUL bytes, in order: the tag
  `pudu-cache-2`, the compiler version, the executable path, the executable size
  in bytes, and the executable modification time. A rebuilt compiler, and so
  every source embedded in it, gets a new identity.
- **Digests.** `hexDigest` writes lowercase hexadecimal, two digits per byte,
  so a digest of 32 bytes is 64 characters.
- **Sharing.** The product cache and the native build cache both take their
  root and identity from here. Neither defines its own.

## Linkage

- **Requires:** [[Pudu Version]].
- **Consumed by:** [[Compiler Cache]], [[Backend Toolchain Cache]].

## Negative Logic (Prohibited Paths)

- No validity decision is made here. The identity names a compiler; the caches
  decide what to reuse.
- The backend does not depend on the compiler's product cache. Only this
  module is shared between the two.
- No directory is created here. Creation belongs to the cache that writes.

## Edge Cases

- `PUDU_CACHE` set to an empty value disables caching, as `off` does.
- An unset `XDG_CACHE_HOME` or an empty one falls back to `~/.cache`.
- A rebuilt executable with the same path, size and modification time gets the
  same identity. The identity relies on the modification time changing.

## Grill Log

- **Q:** Why a module of its own? **A:** The product cache and the native build
  cache must agree on where caches live and on the compiler's name, and the
  backend may not depend on the compiler's product cache. _Rejected:_ defining
  the root in each cache, which lets the two drift apart.
- **Q:** Why hash the identity rather than use the path alone? **A:** A path is
  the same across rebuilds. The size and modification time change when the
  executable is rebuilt, so a rebuilt compiler gets a new name. _Rejected:_ the
  version string alone, which does not separate two builds of one version.
- **Q:** Why does an empty `PUDU_CACHE` disable caching rather than select the
  default root? **A:** The same as `off`: the setting is read as one value, and
  an empty value is treated as a request to turn caching off. _Rejected:_
  treating empty as unset.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Cache]] · [[Backend Toolchain Cache]]
