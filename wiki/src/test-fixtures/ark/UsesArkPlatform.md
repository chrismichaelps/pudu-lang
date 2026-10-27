---
type: module
path: "@root/test-fixtures/ark/UsesArkPlatform.pudu"
fidelity: Active
aliases: [Ark Platform Fixture]
tags: [module, ark, test]
---
# Ark Platform Fixture

Decodes every adapter record kind through [[Ark Input]]'s factory table and skips unknown or
malformed ones; checks press/repeat/release/tap-within-a-frame state, per-frame clearing,
deduplicated bindings, action reads, axes and rebinding; [[Ark Frame Clock]] steps, alpha,
pacing, step-budget drops and a backwards clock; [[Ark Window]] refusals that never reach the
platform and an unknown window. Prints `ark platform: ok`.

## Referenced by

[[Ark Platform Gate]]
