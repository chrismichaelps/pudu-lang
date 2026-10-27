---
type: test
path: "@root/test/package-binary.test.py"
fidelity: Active
tags: [test, release, packaging, size]
aliases: [Package Binary Tests]
---
# Package Binary Tests

## Purpose and interface

`python3 test/package-binary.test.py` exercises the strip boundary in [[Package Binary]] without
changing a real executable. Standard-library unittest imports the script and supplies its existing
argument parser; filesystem tool discovery, host platform and subprocess dispatch are controlled.
No external library, compiler build, network access or repository mutation is required.

## Algorithm and acceptance

macOS must invoke `strip -u -r` so loader-required symbols survive while unused globals are removed.
Linux retains the default command. A path containing spaces remains one subprocess argument.
Windows `.exe` files skip tool discovery and subprocess execution. A missing strip tool produces
the exact parser refusal and exit status 2. A failing tool propagates its CalledProcessError rather
than allowing packaging to continue. Each case restores the patched host state.

The tests assert command and failure contracts; they measure no download size or runtime validity.
Fresh optimized artifact checks, native foreign calls, SQLite execution, copied-bundle execution,
and archive extraction provide the independent evidence those properties require.

## Resolved Grill Log

- **Q:** Treat mocked subprocess success as proof the packaged executable runs? **A:** No. Dispatch
  tests prevent policy regressions; real artifact checks remain separate and use the built compiler.
- **Q:** Change Windows or Linux stripping while repairing Darwin? **A:** No. Their existing command
  and skip behavior are regression contracts.
- **Q:** Hide a missing or failed strip tool? **A:** No. Test exact parser diagnostics and propagate
  process failure, preserving the release refusal boundary.

## Referenced by

[[Package Binary]] · [[src/_MOC]] · [[Backend Performance Delivery]]

## Floating formatter notices (#509)

Copy package-owned regular LICENSE and optional THIRD_PARTY_NOTICES files into
the archive root; older packages without optional notices remain accepted.
Reject symlink/nonregular notice inputs before publishing an archive. Test
exact copied bytes, absence compatibility and refusal; also inspect real source
and binary archives and extracted compiler behavior. Resolved Grill Log:
notice preservation does not change strip policy, input binaries or archive
reproducibility. [[Native Floating Notices]] is required by the current Cabal
source package; the formatter partition must retain it in adapted C.
