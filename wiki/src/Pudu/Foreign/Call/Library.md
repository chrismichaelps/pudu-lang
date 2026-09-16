---
type: module
path: "@root/src/Pudu/Foreign/Call/Library.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium, foreign, ffi]
aliases: [Foreign Call Library]
---

# Foreign Call Library

## Purpose

Load dynamic libraries, resolve native function symbols, manage global library handles and lock-free symbol address caching.

## Interface

```haskell
newtype ForeignHandle = ForeignHandle (Ptr ())

openLibrary   :: Text -> Maybe Text -> IO (Either Text ForeignHandle)
openProcess   :: IO (Either Text ForeignHandle)
candidates    :: Text -> Maybe Text -> [Text]
tryCandidates :: [Text] -> IO (Either Text ForeignHandle)
resolveSymbol :: Text -> Maybe Text -> Text -> IO (Either Text (Ptr ()))
findSymbol    :: ForeignHandle -> Text -> IO (Either Text (Ptr ()))
```

### Governance

- Extracted from `Pudu.Foreign.Call` to keep modules strictly under 500 lines.
- Dynamic libraries are opened once per process and held globally in `openedLibraries` (`MVar (Map (Text, Maybe Text) ForeignHandle)`) to prevent multiple stateful instances of the same native library.
- `"c"` requests the running executable's own process image via `openProcess`, avoiding hardcoded platform-specific libc names.
- `candidates` prioritizes explicit declarations, platform-specific versioned names, and unversioned fallbacks.
- `resolveSymbol` caches function pointers lock-free in `resolvedSymbols` (`IORef (Map (Text, Maybe Text, Text) (Ptr ()))`), ensuring repeated calls pay zero linker lookup overhead.

### Linkage

- **Requires:** `cbits/pudu_ffi.c`.
- **Consumed by:** [[Foreign Call]].

## Algorithm

- `openLibrary` checks `openedLibraries`; if absent, tries `openProcess` for `"c"` or iterates candidates using `c_open` and `c_error`.
- `resolveSymbol` checks `resolvedSymbols`; if absent, resolves library handle, looks up symbol via `c_symbol`, and commits address with `atomicModifyIORef'`.

## Negative Logic (Prohibited Paths)

- No direct invocation or FFI marshalling; parameter preparation and execution belong to [[Foreign Call]].
- No library unloading; handles persist for the life of the process.

## Grill Log

- **Q:** Why extract library loading and symbol resolution into `Pudu.Foreign.Call.Library`?
  **A:** `Pudu.Foreign.Call` was 606 lines. Isolating dynamic library lifecycle, candidate enumeration, and lock-free symbol caching separates host platform loader mechanics from FFI buffer marshalling and invocation, bringing `Call.hs` down to ~380 lines.
- **Q:** Why use `IORef` without locks for `resolvedSymbols`?
  **A:** Symbol addresses are immutable once loaded. Two threads racing to resolve the same symbol perform identical work and write the same pointer, avoiding hot-path lock contention.

## Referenced by

[[Foreign Call]] · [[src/Pudu/_MOC]]
