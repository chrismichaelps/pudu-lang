---
type: script
path: "@root/website/scripts/generate-catalog.sh"
fidelity: Active
tags: [website, generated, documentation]
---
# Website catalogue generator

Builds one deterministic JSON catalogue from every standard-library Pudu source using
`pudu doc --json`, then atomically replaces the runtime data file.

Resolved Grill Log: sort source paths before indexing and never hand-edit generated declarations.
