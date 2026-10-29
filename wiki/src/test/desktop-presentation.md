---
type: module
path: "@root/test/desktop-presentation.mjs"
fidelity: Active
aliases: [Desktop Presentation Gate]
tags: [module, test, desktop]
---
# Desktop Presentation Gate

On macOS compile [[Desktop Presentation Test]] with the desktop, accessibility and menu native
translation units, ARC, warnings as errors and system graphics frameworks. Execute the result,
requiring exact stdout and success. Clean the temporary executable on every exit. Other targets
print a specific unsupported-platform skip. Local full gates and dedicated macOS CI run this test.

## Resolved Grill Log

- **Q:** Accept any zero exit? **A:** No; require the authored exact output too.
- **Q:** Pretend another target tested this adapter? **A:** No; report a skip explicitly.

## Referenced by

[[Desktop Presentation Test]] · [[Repository Gates]] · [[Desktop Presentation Delivery]]
