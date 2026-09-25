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

The executable is stripped before it is packed. Symbol tables are close to half the executable and
nothing reads them at run time. A bundle appends its modules after the executable's last byte, so a
stripped runtime carries them exactly as before, and the archive job's run-from-the-archive check
proves the packaged compiler still starts and runs a program. On macOS only local symbols are removed
(`strip -x`), since the dynamic loader resolves the global ones.

## Negative logic

- A machine without `strip` refuses to package rather than shipping the larger executable.
- A standard library file that is a link, or lies outside the package, is refused.
- An existing archive or checksum is never overwritten.

## Grill Log

- **Q:** Strip in the build instead, with a linker flag? **A:** No. _Rationale:_ the local and test
  builds keep symbols for profiling and crash reports; only the distributed file is stripped.
  _Accepted:_ the packaging step owns what is shipped.
- **Q:** Skip stripping when the tool is missing? **A:** No. _Rationale:_ a release would silently
  double in size. _Accepted:_ refuse.

## Referenced by

[[Release Workflow]] · [[Pudu Package Project]]
