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
pudu run <file>      compile a program and run its main function
pudu doc <file>...   describe every name a program declares
pudu doc --json ...  the same index, for an editor or a search server
pudu doc --html ...  emit a self-contained searchable documentation page
pudu search <query> <file>...  find a name, or a type shape
pudu version         print the version
pudu help            print usage
```

### Governance

- `pudu lsp` speaks the language server protocol over stdio. It takes no arguments and reads until the client closes the stream; everything it answers comes from the same compile the other commands run.
- A refresh installation must overwrite the selected executable path deliberately. Until the
  binary version advances per build, freshness is proven behaviorally: the installed executable
  checks the recent-language compatibility source without diagnostics and passes the real stdio
  LSP session against that same surface. The documented refresh puts that directory first on
  `PATH` and asserts the resolved path before either behavioral check.
- `pudu fmt` rewrites files in place, `--check` reports which would change and exits non-zero without touching any, and `--stdout` writes the result for a caller that wants to diff it. The check form is the shape a continuous-integration step needs.

- `main`'s answer decides what the run does. A whole number becomes the exit status, because that is
  what a shell reads and a program returning one meant it as a status. Unit prints nothing. Anything
  else is printed, so a program that answers with a value can be run and read without writing its
  own output call.

- `pudu run` links the program's dependencies and calls `main` in the root module. A program with
  errors is not run: evaluating a module whose meaning was never established produces a second, less
  useful account of the same defect.
- A run prints its result only when there is one, so a `main` returning unit prints nothing and a
  shell pipeline stays usable.

- `pudu doc` and `pudu search` write the index to stdout and every diagnostic to stderr, so a
  program with errors still yields a machine-readable index rather than a corrupted one.
- Documentation and search finish writing every recoverable result before returning non-zero when
  any indexed root has error diagnostics. Output availability never turns a failed compile into a
  successful process status.
- `pudu doc --json` and `pudu doc` emit the same index. Nothing is expressible in the human form
  that the machine form omits, so a tool never has to scrape the terminal output.
- `pudu doc --html` projects that same index through [[Doc Site]]. It writes one complete page to
  stdout, so redirection chooses the artifact path and the CLI does not invent directory or
  overwrite policy.

- The entry point decides presentation and the library decides meaning: colour, exit codes, and stream choice live here, and nothing here parses or evaluates Pudu.
- Colour is used only for an interactive terminal and never when `NO_COLOR` is set, so piped and redirected output stays plain and diffable.
- `check` treats every named file as a root and compiles its transitive dependency graph through [[Compiler Program]], reporting all diagnostics before failing. Separate roots remain separate invocations until a manifest defines one project graph.
- Exit status is the contract for scripts: zero when no error-severity diagnostic was produced, non-zero otherwise. Warnings alone do not fail.
- Missing, unreadable, or non-file roots flow through [[Compiler Program]] as structured `E2014` diagnostics and produce a non-zero status; the CLI does not race a separate existence probe against the authoritative read. Unknown commands remain stderr usage failures.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Compiler Program]], [[Diagnostic Render]], [[Doc Site]], [[Pudu REPL]], [[Source]].
- **Consumed by:** people and scripts.

## Algorithm

Read arguments, detect the render style once, dispatch to the session or the checker, and exit with the status the results imply.

## Negative Logic (Prohibited Paths)

- No compilation logic, no configuration files, no environment-driven behaviour beyond `NO_COLOR`, and no output that a script cannot interpret from the exit status.
- No direct dependency-path construction; [[Compiler Program]] owns source-root and module-name policy.

## Edge Cases

- `pudu check` with no files is a usage error rather than a silent success.
- `pudu doc --html` with no files is the same explicit usage error as the other documentation
  formats; an intentionally empty site can still be rendered by the pure [[Doc Site]] interface.
- A path may exist and still be unreadable; `check` trusts the loader's diagnostic result, so this cannot become a zero-error summary.
- Standard output is set to UTF-8 by the session so identifiers outside ASCII render correctly.

## Depth

DEPTH 0.35 (SHALLOW by intent). It is the presentation boundary; deepening it would move language behaviour out of the library.

## Grill Log

- **Q:** Should the checker stop at the first failing file? **A:** No. _Rationale:_ a person fixing a project wants every file's diagnostics in one run. _Rejected:_ fail-fast checking.
- **Q:** Where is colour decided? **A:** Here, once, from the terminal and `NO_COLOR`. _Rationale:_ [[Diagnostic Render]] stays pure and testable byte for byte. _Rejected:_ ambient detection inside the renderer.
- **Q:** Should `pudu check B.pudu` ignore `B`'s imports? **A:** No; each argument is a root program and its absolute imports are loaded transitively. _Rationale:_ command-line and REPL loading must compile the program the file declares. _Rejected:_ independent opaque single-file checks.
- **Q:** Should `pudu doc --html` take an output directory? **A:** No. _Rationale:_ the page is one
  artifact and stdout composes with shells, build tools, and release pipelines without defining
  overwrite behaviour in the compiler. _Rejected:_ an output path with implicit replacement.
- **Q:** Should installation rely on Cabal's default binary directory? **A:** Not for a refresh.
  _Rationale:_ the shell may resolve an older executable from another directory first, so the
  documented refresh names `~/.local/bin` and allows overwrite explicitly. _Rejected:_ installing
  successfully somewhere and assuming the editor found that copy.

## Referenced by

[[src/Pudu/_MOC]] · [[Pudu REPL]] · [[Diagnostic Render]] · [[Compiler Pipeline]] · [[Tooling]]
