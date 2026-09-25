---
type: workflow
path: "@root/.github/workflows/public-http-integration.yml"
fidelity: Active
tags: [ci, integration, network]
aliases: [Public HTTP Integration Workflow]
---
# Public HTTP Integration Workflow

The one workflow that reaches the real network, run weekly and on demand rather than on every change,
so an outage elsewhere never blocks a merge. It fetches public HTTP and HTTPS endpoints with Pudu
(`test-fixtures/integration/FetchPublicHttp.pudu`), then reads the live package index from GitHub with
[[website live network check]], authenticated by the workflow's own read-only token.

Resolved Grill Log: network checks stay out of the per-change suites, which use stand-ins; this
workflow is what proves the stand-ins still describe the real services.

## Referenced by

[[website live network check]] · [[src/_MOC]]
