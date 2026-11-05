---
type: module
path: "@root/lib/Std/Desktop/Cli/Template.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, tooling]
aliases: [Std Desktop Cli Template]
---

# Std Desktop Cli Template

## Purpose and interface

The files `pudu desktop init` writes: `files(name, identifier)` answers each relative path with its
content — `pudu-desktop.toml`, `src/Main.pudu`, `frontend/index.html`, `frontend/main.js` and
`frontend/style.css`.

## Semantics

- The generated program registers one typed command and one capability granting it, so a new
  project shows a typed round trip and the deny-by-default model from its first run.
- The name is written into TOML, Pudu and HTML with each format's own escaping.

## Grill Log

- **Q:** Why declare the capability in code rather than a file? **A:** A packaged application runs
  from wherever it is installed, so a file read relative to the working directory would not be found.
  `Capability.load` remains for applications that ship capability files with their resources.

## Dependencies and consumers

Uses [[Std Json]]. Consumed by [[Std Desktop Cli]].

## Referenced by

[[src/Std/_MOC]]
