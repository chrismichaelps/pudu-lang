---
type: module
path: "@root/test/binary.mjs"
fidelity: Active
aliases: [Binary Facade Gate]
tags: [module, test, stdlib, serialization]
---
# Binary Facade Gate

Runs [[Binary Facade Smoke]] through the supplied optimized compiler with exact output. Checks
library/fixture formatting, a positioned E3001 when text is passed to the byte decoder, and the
actual source archive for Std/Binary.pudu. Uses isolated temporary files and bounded child calls.
Registered in [[Repository Gates]] without a new dependency or wall-time performance threshold.

## Resolved Grill Log

- **Q:** Assume a source glob ships the module? **A:** No; inspect the actual archive entries.
- **Q:** Treat a nonzero exit as the requested type error? **A:** No; require its code and location.

## Referenced by

[[Std Binary]] · [[Repository Gates]] · [[src/_MOC]]

Writer admission coverage executes the public encode/decode path at depth 512 and checks
E7001 refusals at the Std.Binary native-call wrapper for depth 513, duplicate Fields and duplicate Choice payloads.
Resolved Grill Log: native-only tests cannot prove that facade wiring exposes the same boundary.

The runtime fault span belongs to binaryEncode inside the library wrapper, not its outer caller.
Resolved Grill Log: preserve that established runtime provenance instead of inventing a caller span.
