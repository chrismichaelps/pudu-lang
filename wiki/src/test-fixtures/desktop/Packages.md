---
type: module
path: "@root/test-fixtures/desktop/Packages.pudu"
fidelity: Active
aliases: [Desktop Packages Fixture]
tags: [module, test, desktop, packaging]
---
# Desktop Packages Fixture

Writes the `.deb`, `.rpm`, NSIS and MSI formats one at a time under `PROBE_DIR`, printing `wrote`,
`missing` (a tool not installed) or `failed` for each, then requires a configuration with an
invalid identifier to be refused. The gate validates what was written with each format's own tool.

## Referenced by

[[Desktop Webview Gate]] · [[Std Desktop Bundle]]
