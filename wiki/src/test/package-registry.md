---
type: script
path: "@root/test/package-registry.py"
fidelity: Active
tags: [registry, packages, e2e]
aliases: [Package registry end-to-end suite]
---
# Package Registry End-to-End Suite

Starts a local registry and a stand-in GitHub backed by real bare git repositories. It drives login, registration, releases, immutable installs, private access, archive refusals, and build-time website snapshot generation through the CLI and HTTP API. A checkout-built CLI is pointed at that checkout's standard library, and registry startup has a bounded wait with a diagnostic log.

See [[architecture/PACKAGES]] · [[registry Test Registry]].

## Grill Log

Resolved Grill Log: real local HTTP and git processes exercise the complete boundary; a failed server startup reports its stderr instead of presenting every later request as a network failure.
