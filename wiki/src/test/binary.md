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

Also execute [[Std Binary Fixture]] with its intentional exit code 22 and empty output. Run
[[Binary Serialization Benchmark]], checking its two report lines and successful consumed round
trips without asserting a machine-specific latency.

## Resolved Grill Log

- **Q:** Assume a source glob ships the module? **A:** No; inspect the actual archive entries.
- **Q:** Treat a nonzero exit as the requested type error? **A:** No; require its code and location.

## Referenced by

[[Std Binary]] · [[Repository Gates]] · [[src/_MOC]]
