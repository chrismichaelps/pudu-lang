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
- `check` treats every named file as a root and compiles its transitive dependency graph through [[Compiler Program]], reporting all diagnostics before failing. Separate roots remain separate invocations until a manifest defines one project graph.
- Exit status is the contract for scripts: zero when no error-severity diagnostic was produced, non-zero otherwise. Warnings alone do not fail.
- Missing, unreadable, or non-file roots flow through [[Compiler Program]] as structured `E2014` diagnostics and produce a non-zero status; the CLI does not race a separate existence probe against the authoritative read. Unknown commands remain stderr usage failures.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Compiler Program]], [[Diagnostic Render]], [[Pudu REPL]], [[Source]].
- **Consumed by:** people and scripts.

## Algorithm

Read arguments, detect the render style once, dispatch to the session or the checker, and exit with the status the results imply.

## Negative Logic (Prohibited Paths)

- No compilation logic, no configuration files, no environment-driven behaviour beyond `NO_COLOR`, and no output that a script cannot interpret from the exit status.
- No direct dependency-path construction; [[Compiler Program]] owns source-root and module-name policy.

## Edge Cases

- `pudu check` with no files is a usage error rather than a silent success.
- A path may exist and still be unreadable; `check` trusts the loader's diagnostic result, so this cannot become a zero-error summary.
- Standard output is set to UTF-8 by the session so identifiers outside ASCII render correctly.

## Depth

DEPTH 0.35 (SHALLOW by intent). It is the presentation boundary; deepening it would move language behaviour out of the library.

## Grill Log

- **Q:** Should the checker stop at the first failing file? **A:** No. _Rationale:_ a person fixing a project wants every file's diagnostics in one run. _Rejected:_ fail-fast checking.
- **Q:** Where is colour decided? **A:** Here, once, from the terminal and `NO_COLOR`. _Rationale:_ [[Diagnostic Render]] stays pure and testable byte for byte. _Rejected:_ ambient detection inside the renderer.
- **Q:** Should `pudu check B.pudu` ignore `B`'s imports? **A:** No; each argument is a root program and its absolute imports are loaded transitively. _Rationale:_ command-line and REPL loading must compile the program the file declares. _Rejected:_ independent opaque single-file checks.

## Referenced by

[[src/Pudu/_MOC]] · [[Pudu REPL]] · [[Diagnostic Render]] · [[Compiler Pipeline]] · [[Tooling]]
