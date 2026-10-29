---
type: module
path: "@root/test-fixtures/desktop/ConfiguresDesktop.pudu"
fidelity: Active
aliases: [Desktop Configure Fixture]
tags: [module, test, desktop]
---
# Desktop Configure Fixture

Calls `desktopConfigure` with a token that names no window: once per refused setting (density
below and above range, a negative limit, a limit past the platform bound, an inverted minimum,
a half or negative aspect ratio), printing each failure message, then once with valid settings,
printing only that it failed. Refusals are decided before any window is looked up, so the
output is identical on every target.

## Referenced by

[[Desktop Configure Gate]]
