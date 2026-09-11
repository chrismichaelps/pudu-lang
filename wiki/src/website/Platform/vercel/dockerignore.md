---
type: build
path: "@root/.dockerignore"
fidelity: Active
tags: [website, vercel, docker]
aliases: [Pudu Docker context]
---
# Pudu Docker Context

Limits the deployment build context to Cabal configuration, compiler sources, and website sources.
It excludes Git data, private book material, local binaries, and generated deployment output.

Resolved Grill Log: a website deployment build cannot receive ignored private manuscript files or
developer-machine artifacts it does not need.
