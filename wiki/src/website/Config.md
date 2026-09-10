---
type: module
path: "@root/website/src/Config.pudu"
fidelity: Active
tags: [website, config]
aliases: [website Config]
---
# Website Config

Reads host, port, connection limit, and catalogue path from environment variables with checked
defaults and typed errors.

Resolved Grill Log: malformed values fail startup rather than silently disabling a bound.
