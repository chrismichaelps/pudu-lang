---
type: script
path: "@root/test/package-install.py"
fidelity: Active
tags: [packages, e2e, cli]
aliases: [Package install suite]
---
# Package Install Suite

Drives `pudu install`, `uninstall`, `deps`, and `tree` from a terminal, the way a package manager is
used day to day, against real bare git repositories reached through `PUDU_GITHUB_URL=file://…`. It
sets `PUDU_MIN_RELEASE_AGE=0` so fresh tags resolve; the age rule is [[Package end-to-end suite]]'s.
Every case checks the exit status, what was printed, and `pudu.toml`, `pudu.lock`, and `deps/`.

The packages are `@alice/json-kit` (1.0.0, 1.1.0, 2.0.0, and the pre-release 2.1.0-beta.1),
`@bob/text` 1.0.0 (which needs `@alice/json-kit` `^1.0`), a git repository `parser` tagged v0.4.0, and
a directory `geometry`.

| Group | Cases |
| --- | --- |
| Adding a package not in `pudu.toml` | Bare install pins `^` of the newest stable release and skips the pre-release. An exact version writes `=`; caret, tilde, and a comma range are written as given; a pre-release named exactly is chosen; two packages install in one command. |
| Repeating and moving | The same command again leaves both files byte-identical. A new exact version moves the lock and reports `~`. A range the lock satisfies keeps it; one it does not moves it. |
| Workflow | A dependency written by hand is locked and installed by plain `pudu install`. A clone without `deps/` is restored without changing the lock. `--locked` passes in sync and refuses a hand-edited requirement, naming the change. `deps` and `tree` show requirements, locked versions, and the transitive package. |
| Other sources | `install ../geometry` writes `geometry = { path = "../geometry" }`; a `git+file://…#v0.4.0` URL writes `parser = { git = …, rev = "v0.4.0" }` and locks it. |
| Transitive | Installing `@bob/text` locks and installs `@alice/json-kit` too. Asking for `@alice/json-kit@2.0.0` beside it is refused naming both requirements. |
| Removal | `uninstall` drops the manifest entry, the lock entry, and the files; two names in one command; a name not in `pudu.toml` is refused. |
| Using what was installed | A program importing the package and its transitive package checks clean, runs, builds into an executable that runs, and a project test importing it passes. Without `deps/`, `pudu check` names the lock entry and says to run `pudu install`. Removing a package makes its import unreadable again (`E2014`). |
| Editor | Through `pudu lsp` on the project's real files: completing after `Parse.` offers the package's exports, hover shows an export's signature and doc comment, definition opens the file under `deps/`, and completing an import offers the package's modules. With the server already running, an import of a package not yet installed is `E2014`; after `pudu install` the next edit clears it and completion works, with no restart. |
| Refusals | A bare word, a trailing `@`, an upper-case handle, `--save-dev`, a version never released (listing those that were), a repository that does not exist, a package owning the project's own module root, and a directory with no `pudu.toml` all exit non-zero, say why, and leave both files as they were. Several packages where one is missing install none. |

See [[architecture/PACKAGES]] · [[Package end-to-end suite]].

## Grill Log

- **Q:** Why a suite beside [[Package end-to-end suite]]? **A:** That suite follows a package's life
  through publishing and the website; this one follows a project through installing. Each stays under
  the file-size limit and can fail on its own.
- **Q:** Why drive the language server here rather than in the LSP session test? **A:** Only here does a
  project have installed packages on disk; what an editor offers from `deps/` is part of installing one.
- **Q:** Why no stand-in API server? **A:** Installing reads only git; leaving the API out proves it.
- **Q:** Why assert that a refused command leaves the files byte-identical? **A:** A package manager
  that half-applies a failed command leaves a project that no longer matches its lock; the
  guarantee that a failure changes nothing is what makes retrying safe.
