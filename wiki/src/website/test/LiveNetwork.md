---
type: test
path: "@root/website/src/Test/LiveNetwork.pudu"
fidelity: Active
tags: [website, packages, integration]
aliases: [website live network check]
---
# Website Live Network Check

The live package index against the real GitHub: `chrismichaelps/pudu-lang-mcp` must be found under the
`pudu-package` topic, admitted with at least one dated release, and have `pudu.toml` among the files
listed at that release's commit. It prints what it found and exits non-zero naming the step that
failed. [[Public HTTP Integration Workflow]] runs it; the per-change suites use [[website live stand]].

Resolved Grill Log: one real package the project owns is the fixture, so the check cannot be broken by
a stranger's repository changing.

## Referenced by

[[Public HTTP Integration Workflow]] · [[website/_MOC]]
