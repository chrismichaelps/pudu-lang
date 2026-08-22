---
type: module
path: "@root/app/Main.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
coupling: 3.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Pudu CLI]
---

# Pudu CLI

## Purpose

Provide the `pudu` executable: start `puduci`, check files, and report version and usage.

## Interface

### Commands

```
pudu                 start the puduci interactive session
pudu repl [file]     start puduci, optionally loading a file
pudu check <file>... compile files and report diagnostics
pudu version         print the version
pudu help            print usage
```

### Governance

- The entry point decides presentation and the library decides meaning: colour, exit codes, and stream choice live here, and nothing here parses or evaluates Pudu.
- Colour is used only for an interactive terminal and never when `NO_COLOR` is set, so piped and redirected output stays plain and diffable.
- `check` compiles every named file and reports all of their diagnostics before failing, so a broken first file cannot hide the rest.
- Exit status is the contract for scripts: zero when no error-severity diagnostic was produced, non-zero otherwise. Warnings alone do not fail.
- A missing file and an unknown command are reported on stderr with a non-zero status, never as a silent no-op.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Diagnostic Render]], [[Pudu REPL]], [[Source]].
- **Consumed by:** people and scripts.

## Algorithm

Read arguments, detect the render style once, dispatch to the session or the checker, and exit with the status the results imply.

## Negative Logic (Prohibited Paths)

- No compilation logic, no configuration files, no environment-driven behaviour beyond `NO_COLOR`, and no output that a script cannot interpret from the exit status.

## Edge Cases

- `pudu check` with no files is a usage error rather than a silent success.
- Standard output is set to UTF-8 by the session so identifiers outside ASCII render correctly.

## Depth

DEPTH 0.35 (SHALLOW by intent). It is the presentation boundary; deepening it would move language behaviour out of the library.

## Grill Log

- **Q:** Should the checker stop at the first failing file? **A:** No. _Rationale:_ a person fixing a project wants every file's diagnostics in one run. _Rejected:_ fail-fast checking.
- **Q:** Where is colour decided? **A:** Here, once, from the terminal and `NO_COLOR`. _Rationale:_ [[Diagnostic Render]] stays pure and testable byte for byte. _Rejected:_ ambient detection inside the renderer.

## Referenced by

[[src/Pudu/_MOC]] · [[Pudu REPL]] · [[Diagnostic Render]] · [[Compiler Pipeline]] · [[Tooling]]
