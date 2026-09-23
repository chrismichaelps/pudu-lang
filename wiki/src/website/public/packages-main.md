---
type: script
path: "@root/website/public/assets/packages/main.js"
fidelity: Active
tags: [website, packages, asset]
aliases: [Package install controls]
---
# Package Install Controls

Enhances the native install disclosure with a version picker that rewrites the displayed command and copy buttons for commands and import lines. It binds the Source tab's file filter and [[Package source navigation]]. It also observes a bounded list's next-page link, fetches the next HTML page near the scroll edge, and appends only its rows. The link remains usable on failure or without script.

See [[architecture/PACKAGES]] · [[website View Packages Frame]].

## Grill Log

Resolved Grill Log: static instructions remain readable without JavaScript, and the script only copies visible commands from the page.
