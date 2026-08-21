---
type: subsystem
tags: [subsystem]
aliases: [Tooling]
---

# Tooling

## Purpose

Expose one consistent compiler pipeline through CLI, REPL, formatter, linter, project/package workflows, documentation generation, tests, and eventually LSP.

## Owns

CLI command model · REPL session model · formatter · lints · project manifest/lockfile · documentation · process exit mapping.

## Boundaries

- Reuses structured values and [[Diagnostic]] rendering; it does not reimplement compiler phases.
- Filesystem, terminal, environment, and process IO remain at Tooling or explicit seams.
- Tool output and exit codes are compatibility-tested public interfaces.

## Grill Log

- **Q:** Should package management precede the compiler core? **A:** Specify it now but implement after single-project compilation stabilizes. _Rationale:_ production compatibility needs a model, while early network resolution would distract from semantics. _Rejected:_ ignoring manifests until v1.
- **Q:** Should the REPL bypass modules/types for convenience? **A:** No; wrap entries in a synthetic session module and run the same phases. _Rationale:_ two semantic modes would undermine trust. _Rejected:_ dynamically typed REPL evaluator.

## Referenced by

[[architecture/OVERVIEW]] · [[Frontend]] · [[Semantics]] · [[Runtime]] · [[Backend]]
