---
type: script
path: "@root/scripts/package-binary.py"
fidelity: Active
tags: [release, packaging, size]
aliases: [Package Binary]
---
# Package Binary

Turns a built compiler into the archive [[Release Workflow]] publishes: `bin/pudu`, the standard
library under `lib/pudu`, `LICENSE`, and a `package.json` naming the version, target, and layout,
packed as a reproducible `tar.gz` (fixed owner, modes, and `SOURCE_DATE_EPOCH` times) beside its
SHA-256.

## Interface and algorithm

`main` accepts `--binary`, `--target`, optional `--package` and optional `--output`. It checks the
compiler version and API lifecycle before staging a copy of the executable and the package-owned
standard library. `strip(executable, parser)` removes unused symbols from that staged compiler;
the input build is never modified. Windows `.exe` files retain their existing packaging policy.

On macOS `strip -u -r` preserves undefined and dynamically referenced symbols while removing unused
global symbols as well as local symbols. On other non-Windows targets the platform's default strip
policy remains in place. Stripping happens before any program is attached; a bundle subsequently
built from the packaged compiler uses that stripped runtime. Stripping an already attached program
is outside this packaging contract.

The reproducible archive fixes gzip and entry times, ownership and modes; its SHA-256 file names the
archive. [[Package Binary Tests]] verifies strip dispatch and refusal. Real optimized compiler checks
must also prove Mach-O validity, signature verification, native C/C++ calls, the reserved SQLite
adapter, and execution after archive extraction. Unit dispatch tests alone do not establish those
runtime properties.

Verified 2026-10-16 on the optimized GHC 9.10.3/aarch64 compiler (98,037,480 bytes): the packaged
65,766,184-byte executable stays a thin arm64 Mach-O (`NOUNDEFS`) with its ad-hoc linker signature
(`codesign --verify` passes), keeps the identical 13-dylib link list, and answers `pudu 0.1.3`
after archive extraction. Extracted-library runs of the Loop benchmark and five DB fixtures
(including a real `sqlite::memory:` open through the dlopen'ed `libsqlite3.dylib` adapter) and
foreign-boundary refusals are byte-identical to the unstripped compiler, and `pudu build` from the
stripped compiler writes a working attached bundle 32.9% smaller (65.8 MB versus 98.0 MB). The
archive checksum matches its `.sha256` sidecar.

## Negative logic

- A machine without `strip` refuses to package rather than shipping the larger executable.
- A standard library file that is a link, or lies outside the package, is refused.
- An existing archive or checksum is never overwritten.
- Strip failures propagate; no archive is published after a failed strip.

## Resolved Grill Log

- **Q:** Strip in the build instead, with a linker flag? **A:** No. _Rationale:_ the local and test
  builds keep symbols for profiling and crash reports; only the distributed file is stripped.
  _Accepted:_ the packaging step owns what is shipped.
- **Q:** Skip stripping when the tool is missing? **A:** No. _Rationale:_ a release would silently
  double in size. _Accepted:_ refuse.
- **Q:** Preserve every global symbol on macOS? **A:** No. `-u -r` retains the loader's undefined and
  dynamically referenced symbols. The reserved SQLite module uses a fixed native table rather than
  executable exports. Real foreign-boundary checks remain required because dynamically loaded
  libraries are part of the compiler's supported behavior.
- **Q:** Claim a smaller native Pudu program from this change? **A:** No. Download bytes describe
  the compiler archive; a Pudu bundle still carries the Haskell compiler/evaluator. Report raw binary
  bytes and archive bytes separately, with source and build provenance.

## Referenced by

[[Release Workflow]] · [[Pudu Package Project]] · [[Package Binary Tests]] ·
[[Backend Performance Delivery]] · [[Performance Constitution]]

## Floating formatter notices (#509)

Copy package-owned regular LICENSE and optional THIRD_PARTY_NOTICES files into
the archive root; older packages without optional notices remain accepted.
Reject symlink/nonregular notice inputs before publishing an archive. Test
exact copied bytes, absence compatibility and refusal; also inspect real source
and binary archives and extracted compiler behavior. Resolved Grill Log:
notice preservation does not change strip policy, input binaries or archive
reproducibility. [[Native Floating Notices]] is required by the current Cabal
source package; the formatter partition must retain it in adapted C.
