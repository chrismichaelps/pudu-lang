---
type: module
path: "@root/test-fixtures/desktop/Updates.pudu"
fidelity: Active
aliases: [Desktop Updates Fixture]
tags: [module, test, desktop, updates]
---
# Desktop Updates Fixture

Publishes a signed beta release with a patch from the running version into `PROBE_DIR/serve`, then
against `PROBE_PORT`: a stable subscriber sees no update, a beta subscriber finds it after an
endpoint that answers `404`, the full and patched downloads both rebuild the release archive, a
download signed by an untrusted key is refused, the install swaps the version, the first start is
pending and the second, unconfirmed, rolls back to the previous version.

## Referenced by

[[Desktop Webview Gate]] · [[Std Desktop Update]]
