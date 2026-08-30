---
type: subsystem
tags: [subsystem]
aliases: [Tooling]
---

# Tooling

- [[Language Server]] — `pudu lsp`, which answers an editor from the ordinary compile so the editor and the command line can never disagree.
- [[Format]] — `pudu fmt`, the one committed style, applied from the token stream so it can only move whitespace.

## Purpose

Expose one consistent compiler pipeline through CLI, REPL, formatter, linter, project/package workflows, documentation generation, tests, and eventually LSP.

## Owns

CLI command model · REPL session model · formatter · lints · project manifest/lockfile · documentation · process exit mapping.

## Boundaries

- Reuses structured values and [[Diagnostic]] rendering; it does not reimplement compiler phases.
- Filesystem, terminal, environment, and process IO remain at Tooling or explicit seams.
- Tool output and exit codes are compatibility-tested public interfaces.
- A refresh installation replaces the executable the shell and editor actually resolve, then
  drives that installed binary through both `check` and a real LSP session. The package version
  alone cannot prove freshness while pre-release builds still share `0.1.0.0`; the refresh asserts
  the resolved path first so another earlier `PATH` entry cannot make the proof vacuous.
- Generated documentation has one canonical [[Doc Index]] and may be projected as terminal text,
  [[Doc Json]], or a self-contained [[Doc Site]]; projections do not re-infer declarations.

## Grill Log

- **Q:** Should package management precede the compiler core? **A:** Specify it now but implement after single-project compilation stabilizes. _Rationale:_ production compatibility needs a model, while early network resolution would distract from semantics. _Rejected:_ ignoring manifests until v1.
- **Q:** Should the REPL bypass modules/types for convenience? **A:** No; wrap entries in a synthetic session module and run the same phases. _Rationale:_ two semantic modes would undermine trust. _Rejected:_ dynamically typed REPL evaluator.
- **Q:** Does the documentation website require a hosted service? **A:** No; emit one static page.
  _Rationale:_ the index is immutable compiler output, and offline documentation must remain useful
  in a systems-language toolchain. _Rejected:_ a required server or browser build pipeline.
- **Q:** Is a successful build enough to call the editor installation current? **A:** No; exercise
  the installed path. _Rationale:_ an older `pudu` elsewhere on `PATH` can keep serving stale
  diagnostics even when the worktree build is correct. _Rejected:_ checking only `pudu version`,
  because pre-release builds currently share one binary version.

## Referenced by

[[architecture/OVERVIEW]] · [[Frontend]] · [[Semantics]] · [[Runtime]] · [[Backend]]
