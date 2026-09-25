---
type: module
path: "@root/website/src/Config.pudu"
fidelity: Active
tags: [website, config]
aliases: [website Config]
---
# Website Config

Reads host, port, connection limit, catalogue path, package snapshot path (`PUDU_PACKAGES_PATH`), and documentation directory
(`PUDU_DOCS_PATH`, default `website/docs`) from environment variables with checked defaults and typed
errors.

Resolved Grill Log: malformed values fail startup rather than silently disabling a bound.
