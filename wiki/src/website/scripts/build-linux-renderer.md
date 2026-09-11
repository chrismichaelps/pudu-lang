---
type: script
path: "@root/website/scripts/build-linux-renderer.sh"
fidelity: Active
tags: [website, pudu, linux, build]
aliases: [Linux Pudu renderer builder]
---
# Linux Pudu Renderer Builder

Builds the compiler and the website's bundled Pudu HTTP server in a Linux x86-64 container, then
places the executable under `website/bin/` for Vercel assembly.

Resolved Grill Log: deployment-native binaries are built on the same operating-system and CPU
family as the target function, never copied from the developer's macOS build.
