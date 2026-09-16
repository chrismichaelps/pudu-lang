---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Bundle.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.9
tags: [module, bundle, packaging]
aliases: [Pudu Bundle]
---

# Pudu Bundle

## Purpose

Package a Pudu program and compiler into a single self-executing executable artifact by
appending program modules and a binary trailer to the compiler binary.

## Interface

### Signatures

```haskell
data Bundle = Bundle
  { bundleEntry :: !Text
  , bundleModules :: ![(Text, Text)]
  }

bundleOf :: ModuleName -> Map ModuleName Source -> Bundle
writeBundled :: FilePath -> Bundle -> IO ()
attachedBundle :: IO (Maybe Bundle)
materialise :: FilePath -> Bundle -> IO FilePath
```

- `bundleOf` constructs a deterministic bundle from discovered module sources, sorting modules by name.
- `writeBundled` copies the current compiler binary, appends the encoded bundle payload, padded size,
  and trailer marker, setting executable permissions.
- `attachedBundle` inspects the running binary's trailer to detect and decode an attached bundle.
- `materialise` unpacks bundled modules into a target directory, validating module names and structure,
  and returns the entry module's path.

### Governance

- The executable trailer uses a fixed marker (`\n--pudu-bundle--\n`) and fixed-width 16-digit byte count,
  enabling O(1) trailer probing without reading the whole binary.
- Materialisation validates all module names against valid identifier segment rules, rejects duplicates,
  and requires the declared entry module to be present, preventing arbitrary path traversal.
- Module materialisation writes files only if not already present.
- Bundles interpret the contained modules using the embedded compiler; this packages distribution rather
  than native machine code generation.

### Linkage

- **Requires:** [[Source]], [[Syntax Name]], `System.Directory`, `System.FilePath`.
- **Consumed by:** [[Pudu CLI]] (`pudu build --bundle`), `Main.hs` (`runBundled`).

## Algorithm

1. `writeBundled`: read executable bytes via `getExecutablePath`, serialize module count and UTF-8 encoded
   module pairs, append 16-byte zero-padded length, and append trailer marker.
2. `attachedBundle`: seek to `filesize - (markerLength + 16)`, check trailer marker, read length, seek
   backward to bundle payload, and decode.
3. `materialise`: validate segments in module names, ensure unique module set, write each module to its
   relative `.pudu` file path, and return the resolved root path.

## Negative Logic (Prohibited Paths)

- Never allow unsanitized module paths that escape the target root directory (path traversal guard).
- Never modify running binary in-place: bundle creation always writes to a new target path.
- No global cache directory: bundle execution isolates unpacked modules into a per-run temporary directory.

## Grill Log

- **Q:** Why append modules to the binary rather than embedding via linker or C compiler?
  **A:** Appending works across all host platforms without requiring external C toolchains or relinking.
  OS binary loaders read headers and mapped segments, ignoring appended trailing data.
- **Q:** Why materialise modules to disk instead of evaluating directly from memory?
  **A:** Pudu compiler's module discovery and diagnostic paths expect physical source files and canonical
  paths matching module names; disk materialisation ensures 100% parity with standalone development.

## Referenced by

[[src/Pudu/_MOC]] · [[Pudu CLI]] · [[pudu-cabal]]
