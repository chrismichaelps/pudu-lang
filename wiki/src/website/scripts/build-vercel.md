---
type: script
path: "@root/website/scripts/build-vercel.sh"
fidelity: Active
tags: [website, vercel, build]
aliases: [Vercel output builder]
---
# Vercel Output Builder

Produces a Build Output API v3 directory from a Linux Pudu server, the public catalogue, the thin
Node adapter, static assets, and canonical HTML captured from a local Pudu server. Its extensionless
rewrites include every fixed canonical page, including about and donation. It refuses a missing or non-Linux
server.

Resolved Grill Log: the script assembles deterministic deployment output but does not compile a
macOS binary for Linux or hide architecture mismatch. Dynamic search alone reaches the function.
