---
type: module
path: "@root/src/Pudu/Compiler/Cache.hs"
fidelity: Active
domain: "[[Compiler Pipeline]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.8
depth_status: DEEP
coupling: 4.0
interface_stability: 0.7
tags: [module, deep, performance, cache, incremental]
aliases: [Compiler Cache]
---

# Compiler Cache

## Purpose

Keep unchanged modules' compiled products across compiler runs, stored under the fingerprint of
everything each was made from, so a lookup finds the product of exactly this input or nothing.

## Interface

```haskell
data ProductCache
disabledCache :: ProductCache
openProductCache :: IO ProductCache            -- PUDU_CACHE / XDG_CACHE_HOME / ~/.cache
openProductCacheAt :: FilePath -> IO ProductCache
lookupFrontend :: ProductCache -> Source -> IO (Maybe Module)
storeFrontend :: ProductCache -> Source -> Module -> IO ()
lookupChecked :: ProductCache -> ByteString -> Source -> IO (Maybe CheckedProduct)
storeChecked :: ProductCache -> ByteString -> Source -> CheckedProduct -> IO ()
interfaceFingerprint :: ProductCache -> Module -> Maybe ByteString
interfaceKey :: ProductCache -> Source -> IO ByteString
graphFingerprint :: [(Text, ByteString)] -> ByteString
pruneProducts :: ProductCache -> IO ()
```

## Governance

- **Two products.** A *frontend* entry — the parsed module and its interface key — is keyed by the
  source text alone. A *checked* entry — the expanded module, what each integer literal became, and
  the constants folding froze —
  is keyed by the source text and the graph key: every module's name and interface key.
- **Interface keys are position-free.** They cover a module's imports, body-free exported
  declarations, private type shells, exported constants' annotations, default availability, and
  every exported name, written against a source no module is. Editing a body or moving code leaves
  other modules' checked products reusable; any change another module could observe re-keys them.
- **Only clean products are stored.** A parse or check with any diagnostic is never stored, so every
  diagnostic is produced fresh by the compiler reporting it.
- **Integrity.** Every entry ends with a BLAKE2b digest of its payload, is written to a temporary
  file and renamed into place, and is a miss when it does not verify. A failed write removes its
  temporary file. A cache that cannot be opened or written is no cache; compiling never depends on it.
- **Isolation.** Entries live under a directory named by the compiler's version and executable
  identity; a different compiler reads none of them and removes directories it cannot read.
- **Bounded.** A compile that stored something prunes the directory to half of 4096 entries,
  least recently read first; reading an entry marks it used.
- `PUDU_CACHE=off` disables it; any other value names the root.

## Linkage

- **Requires:** [[Cache Persist]], [[Source]], [[Type Interface]], [[Semantic Interface]],
  [[Pudu Version]].
- **Consumed by:** [[Compiler Program]], [[Pudu CLI]].

## Negative Logic (Prohibited Paths)

- No timestamp-based validity; content decides. No stored diagnostics, tokens, resolutions, or
  documentation. No live evaluator state.

## Edge Cases

- A file rewritten with the same length and timestamp is a different key.
- Damaged or truncated entries fall back to source and are replaced.
- Concurrent compilers each rename complete entries into place.

## Grill Log

- **Q:** Key checked products by every module's text? **A:** No; by interface keys. _Rationale:_ a
  body edit would otherwise re-check the whole standard library. _Rejected:_ whole-text graph keys.
- **Q:** Store only products without diagnostics? **A:** Yes. _Rationale:_ diagnostics may mention
  other modules' positions, which interface keys ignore. _Rejected:_ caching diagnostics.
- **Q:** Validate by timestamps? **A:** No; content is hashed. _Rejected:_ mtime/size shortcuts.

## Measurement

See [[2026-09-21-product-cache]].

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Program]] · [[Cache Persist]]
