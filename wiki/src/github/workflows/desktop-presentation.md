---
type: module
path: "@root/.github/workflows/desktop-presentation.yml"
fidelity: Active
aliases: [Desktop Presentation CI]
tags: [module, test, delivery, desktop]
---
# Desktop Presentation CI

Run [[Desktop Presentation Gate]] on macOS for changes to the native boundary, harness, runner
or this workflow. Checkout and the existing runner toolchain suffice; no compiler dependency
build or desktop automation is required. Include PRs and pushes to dev/feature branches.

## Resolved Grill Log

- **Q:** Rely on Linux to validate native drawing? **A:** No; execute the system graphics boundary.
- **Q:** Rebuild the full language to check row orientation? **A:** No; compile the actual adapter directly.

## Referenced by

[[Desktop Presentation Gate]] · [[Desktop Presentation Delivery]]
