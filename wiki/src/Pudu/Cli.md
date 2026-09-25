---
type: module
path: "@root/packages/pudu/v0.1/app/Main.hs"
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
pudu lint [--json] [--fix] [--allow CODE] <path>...  analyze files or directories
pudu run <file>      compile a program and run its main function
pudu watch <file>    watch project sources and restart program on change
pudu test [path]...  discover and execute test fixtures, reporting assertion summaries
pudu init [path] [--name @owner/repo] [--lib]   scaffold an application or package library
pudu doc <file>...   describe every name a program declares
pudu doc --json ...  the same index, for an editor or a search server
pudu doc --html ...  emit a self-contained searchable documentation page
pudu search <query> <file>...  find a name, or a type shape
pudu install | uninstall | update | upgrade | deps | tree   package commands ([[architecture/PACKAGES]])
pudu login | logout | whoami | release <version> | search <words>...   publication commands
pudu version         print the version
pudu help            print usage
```

### Governance

- `check`, `run`, `explain`, and `test` compile through the [[Compiler Cache]]: unchanged modules'
  products from earlier runs are reused. `PUDU_CACHE=off` compiles everything from source.

- `pudu lsp` speaks the language server protocol over stdio. It takes no arguments and reads until the client closes the stream; everything it answers comes from the same compile the other commands run.
- A refresh installation must overwrite the selected executable path deliberately. Until the
  binary version advances per build, freshness is proven behaviorally: the installed executable
  checks the recent-language compatibility source without diagnostics and passes the real stdio
  LSP session against that same surface. The documented refresh puts that directory first on
  `PATH` and asserts the resolved path before either behavioral check.
- `pudu fmt` rewrites files in place, `--check` reports which would change and exits non-zero without touching any, and `--stdout` writes the result for a caller that wants to diff it. The check form is the shape a continuous-integration step needs.
- `pudu lint` delegates to [[Pudu CLI Lint]]. It reuses the typed compiler result, includes existing
  compiler warnings as native rules, supports deterministic human/JSON output and narrow explicit
  suppression, and applies only source-verified safe edits before recompiling.

- `main`'s answer decides what the run does. A whole number becomes the exit status, because that is
  what a shell reads and a program returning one meant it as a status. Unit prints nothing. Anything
  else is printed, so a program that answers with a value can be run and read without writing its
  own output call.

- `pudu run` links the program's dependencies and calls `main` in the root module. A program with
  errors is not run: evaluating a module whose meaning was never established produces a second, less
  useful account of the same defect.
- A run prints its result only when there is one, so a `main` returning unit prints nothing and a
  shell pipeline stays usable.

- `search` names two commands. When every argument after the query is an existing path it is the
  declaration search over those sources; otherwise the words search published packages. The
  declaration form predates package search and keeps its meaning.
- `pudu help` lists the package and publication commands a generated project's README names.

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

- `pudu test` discovers `.pudu` test files under `test/`, `tests/`, or the paths provided on the command line. It compiles and evaluates each file, tallying assertions and failures. It reports a clean test suite summary and exits with code 0 on all pass, or code 1 on any failure.
- `pudu init` delegates project creation to [[Pudu CLI Init]]. It initializes a canonical
  `pudu.toml`, runnable source, an executable test, README, and ignore file. Existing regular
  scaffold files are preserved, while an existing manifest, symlink, or incompatible filesystem
  object is refused before managed content is written.
  Generated application code is Pudu-only and forms the graph `Main → App.Greeting →
  Domain.Greeting`; the effectful composition root depends inward on pure policy, never the reverse.
  `--lib` instead writes a root-owned library module and its test. `--name` selects an identity
  validated by the package system, including a publishable `@owner/repo`.
- `pudu watch` watches the project root enclosing the specified file, automatically restarting the program on source changes:
  - Scopes child process lifetime using `bracket`, ensuring that terminating or re-spawning a process terminates the running handle and reaps the exit status before launching the next iteration.
  - Debounces rapid saves using a 100ms settling loop until both file modification times and file sizes stabilize.
  - Traverses directory trees with symlink cycle detection via canonicalized ancestor path tracking.
  - Monitors both `.pudu` sources and `pudu.toml` manifest files, skipping build/tool directories (`.git`, `.pudu`, `dist-newstyle`, `node_modules`, `target`).
  - Reports changed file names using fast `Map` difference indexing.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Compiler Program]], [[Diagnostic Render]], [[Doc Site]], [[Pudu REPL]], [[Source]].
- **Consumed by:** people and scripts.

## Algorithm

Read arguments, detect the render style once, dispatch to the session, checker, runner, test discovery runner, or initializer, and exit with the status the results imply.

## Negative Logic (Prohibited Paths)

- No compilation logic or environment-driven behaviour beyond `NO_COLOR`, and no output that a
  script cannot interpret from the exit status. Project lint policy is owned by [[Pudu CLI Lint]],
  not parsed in this entry point.
- No direct dependency-path construction; [[Compiler Program]] owns source-root and module-name policy.
- `pudu init` must never overwrite an existing `pudu.toml`.

## Edge Cases

- `pudu check` with no files is a usage error rather than a silent success.
- `pudu test` with no matching test files reports that zero test suites were discovered and exits with an informative message.
- `pudu init` on an existing package reports that `pudu.toml` already exists and refuses modification.
- Directory-derived package names are normalized to the lowercase ASCII/hyphen grammar; a name
  with no admissible characters or one claiming the reserved `std` or `core` namespace is refused.
- A concurrent initializer cannot interleave scaffold writes. The manifest is committed last, so
  it never marks a project complete before every newly managed file has reached its destination.
- `pudu doc --html` with no files is the same explicit usage error as the other documentation
  formats; an intentionally empty site can still be rendered by the pure [[Doc Site]] interface.
- A path may exist and still be unreadable; `check` trusts the loader's diagnostic result, so this cannot become a zero-error summary.
- Standard output is set to UTF-8 by the session so identifiers outside ASCII render correctly.

## Depth

DEPTH 0.35 (SHALLOW by intent). It is the presentation boundary; deepening it would move language behaviour out of the library.

## Grill Log

- **Q:** Should `pudu search` belong to the package commands alone? **A:** No. _Rationale:_ the
  declaration search `search <query> <file>...` shipped first and is documented; existing paths
  after the query are an unambiguous signal, and package words are not paths. _Rejected:_ a
  renamed declaration search; dispatch by argument count.
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
- **Q:** How should `pudu test` discover test fixtures when no paths are passed?
  **A:** Search standard directory paths `test/`, `tests/`, and `test-fixtures/` for `.pudu` files, or allow specific test file targets.
  _Rationale:_ Standardizes project discovery without requiring rigid test manifests.
- **Q:** How are assertion counts and outcomes communicated by `pudu test`?
  **A:** Each test file is evaluated via `evaluateProgramEntry`. An integer exit code represents the count of assertions held. A panic, exception, or runtime error is treated as a test failure. The CLI prints individual test progress, passed assertion counts, total elapsed count, and exits with 0 on all tests passing, or non-zero if any test failed.
- **Q:** What does `pudu init` generate?
  **A:** It creates a canonical `pudu.toml` with identity, version, language, source, and package
  metadata; a runnable application or a root-owned library with `--lib`; a test, README, and
  `.gitignore`. It never overwrites an existing `pudu.toml`.
  _Rationale:_ Protects existing project configurations while providing immediate onboarding.
- **Q:** Refuse a directory merely because it already contains `src/Main.pudu` or a test?
  **A:** No. _Rationale:_ `init` is also how an existing source directory becomes a canonical
  project; regular files are preserved and only missing scaffold pieces are created. _Rejected:_
  overwriting source; requiring an empty directory.
- **Q:** Require a new Pudu developer to edit Haskell? **A:** No. The generated manifest, source
  graph, and tests contain Pudu only. Haskell remains an implementation language of the current
  bootstrap compiler until the separately governed self-hosting milestone; it is not part of an
  initialized project's source or build workflow.

## Referenced by

[[src/Pudu/_MOC]] · [[Pudu REPL]] · [[Diagnostic Render]] · [[Compiler Pipeline]] · [[Tooling]]

## Manifest string escaping

Project initialization normalizes its directory-derived package name to the package grammar rather
than merely escaping arbitrary text into TOML. Existing regular files remain preserved. The
initialization module's focused filesystem properties and the end-to-end generated-project gate are
the readiness evidence.

## Initialization path validation and bundle isolation

`pudu init` normalizes and validates target directory paths, preventing accidental target escapes. It populates `package.language` with the canonical minor-bounded constraint from `Pudu.Version`. Bundled binary execution (`runBundled`) extracts attached modules into an isolated per-process temporary directory using `withSystemTempDirectory "pudu-bundle"`, and reliably restores environment modifications via `bracket`.

`pudu build` compiles through an in-memory product cache and includes the collected entries in the
bundle. `runBundled` seeds an in-memory cache from those entries when the bundled compiler version
matches. An older bundle or mismatched version compiles from the bundled sources. Bundle execution
never opens or prunes the host product cache ([[Compiler Cache]], [[Pudu Bundle]]).
When `--runtime` names an executable, the build attaches only source modules: that executable's
cache compatibility cannot be established from its version string.

### Resolved Grill Log

- **Q:** Cache unpacked bundle modules across runs? **A:** No; isolated temporary directories prevent stale cache poisoning and concurrent collision between different bundle versions.
- **Q:** Where should a bundle read its compiled products? **A:** From its own payload, verified by
  the ordinary product-cache reader. _Rationale:_ its executable identity differs from the build
  executable and must not remove another program's cached products. _Rejected:_ sharing the host
  cache directory between distinct bundled executables.
- **Q:** Hardcode project template language constraint? **A:** No; derive it directly from the active Cabal compiler version via `languageConstraint`.
- **Q:** Why scope watched child processes using `bracket`? **A:** Unhandled watcher exits, signals, or rapid crashes could leave orphaned zombie background processes holding TCP ports or file locks. `bracket` guarantees `terminateProcess` and `waitForProcess` run on every restart and exit.
- **Q:** Why debounce with a 100ms settling loop in `pudu watch`? **A:** Editors and build tools frequently write temporary files, touch files, or perform multi-stage saves. Checking that timestamps and file sizes remain unchanged across 100ms prevents spurious mid-save recompilation.
- **Q:** Why track symlink ancestors during watch directory walks? **A:** Recursive directory symlinks can induce infinite loops and stack exhaustion in tree walkers. Canonicalizing paths and maintaining an ancestor `Set` stops circular traversals immediately.

## Products onto named runtimes (#352)

`pudu build --runtime` asks [[Pudu Bundle]] `sharesSources` and carries the checked products when
the runtime shares this compiler's source digest; otherwise it carries none and says the program
will be checked each time it starts. `bundledCache` compares a bundle's products against
`identityText`, not the bare version.
