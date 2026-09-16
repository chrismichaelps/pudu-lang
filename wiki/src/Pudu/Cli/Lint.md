---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/Lint.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, lint]
aliases: [Pudu CLI Lint]
---

# Pudu CLI Lint

## Purpose and interface

Own `pudu lint`: path discovery, [[Pudu Lint Config]] integration, compiler-warning adaptation, source-local
suppression, human and JSON projection, atomic safe-fix persistence, and exit status. The public
library entry is `runLint`, returning a `LintRun` value instead of terminating the process so CLI
behavior can be tested without a child shell.

Accepted options are `--json`, `--fix`, and repeatable `--allow CODE`; every remaining argument is a
file or directory. Directories are traversed deterministically for `.pudu` files while tool/build
directories and symbolic links are not followed. With no path, the command reports a usage error.

## Configuration and suppression

The nearest `pudu.toml` may contain:

```toml
[lint]
allow = ["W2001", "W7101"]
```

Only registered five-character warning codes are admitted. Malformed lint configuration is a typed command
failure, never silently ignored. CLI allowances extend the project list. Source comments provide
the narrow exceptions `// pudu-lint: allow-file W7101` and
`// pudu-lint: allow-next W7101`; unknown codes or malformed directives are errors. `allow-next`
applies only to the next physical line.

## Output, fixes, and status

Human output reuses the canonical diagnostic renderer. JSON is one array of objects containing
path, scalar offsets, one-based line/column, code, severity, rule, message, help, and a nullable fix
with explicit applicability and replacement. Compiler errors remain present and prevent lint
analysis from pretending an invalid program was checked.

`--fix` writes only `Safe` edits. Each changed file is staged beside the destination and renamed
over it; after persistence the command recompiles and reports the remaining findings. Any compiler
error, configuration error, or unsuppressed finding makes the command unsuccessful. A completely
fixed run succeeds.

## Grill Log

- **Q:** Lint transitive dependencies every time one root is named? **A:** No. _Rationale:_ project
  dependencies and the standard library are not owned by that source argument, and directory mode
  already names each owned file. _Accepted:_ report dependency compile errors, but adapt warnings and
  native rules only for each named root.
- **Q:** Hide malformed suppression as an ordinary comment? **A:** No. _Rationale:_ a misspelled
  exception would make CI policy appear active while doing nothing.
- **Q:** Rewrite a file that still has compiler errors? **A:** No. _Rationale:_ typed equivalence was
  not established. _Rejected:_ best-effort fixes on an invalid tree.
- **Q:** Follow directory symlinks? **A:** No. _Rationale:_ they can escape ownership or form cycles.

## Referenced by

[[Pudu CLI]] · [[Pudu Lint]] · [[Pudu CLI Lint Spec]] · [[Repository Gates]]
