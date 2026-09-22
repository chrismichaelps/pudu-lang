# Dependencies

A project uses code other people wrote by naming it in `pudu.toml` and running `pudu install`. The command chooses a version of everything needed, records the choice and a digest of its content in `pudu.lock`, and puts the code in `deps/`, where the compiler, the editor, and you can all read it. There is no second tool: every command on this page is part of `pudu`.

## Installing a dependency

Name what you want to install: a package from the registry, a directory on your machine, or a git repository at a tag, branch, or commit:

```sh
pudu install @alice/json-schema
pudu install @alice/json-schema@1.4.2
pudu install ../geometry
pudu install https://github.com/carol/parser.git#v0.4.0
```

A registry package is `@handle/name`. Without a version, `pudu install` takes the newest release and writes a requirement compatible with it (`^1.4.2`); with `@1.4.2` it takes exactly that release.

While it works, one line at the bottom of the terminal shows what it is doing — fetching a repository, copying a package — and how long it has taken. When it is done, `pudu install` says where each package came from, what changed, and what to import:

```text
Resolved 1 package in 612ms · 1 fetched
Packages: +1
  + parser 0.4.0
Installed 1 package into deps/ in 21ms
Wrote pudu.toml, pudu.lock

parser provides the modules under Parser, such as:
  import Parser.Json

Done in 640ms
```

Run it again and nothing is fetched: the lock names a commit the machine already has.

```text
Resolved 1 package in 1ms · 1 from cache
Already up to date

Done in 9ms
```

`--verbose` prints every step as its own timed line, which is what to read when something is slow; `--quiet` prints nothing unless there is an error.

A dependency's modules are imported by their names, exactly like the project's own:

```text
import Parser.Json as Json
```

`pudu check`, `pudu run`, `pudu test`, and the editor find installed packages without being told.

## What gets written

`pudu.toml` gains one line for each dependency. A directory is used where it is; a repository is checked out at the revision named:

```toml
[dependencies]
geometry = { path = "../geometry" }
parser = { git = "https://github.com/carol/parser.git", rev = "v0.4.0" }
```

`pudu.lock` records exactly what was installed: the commit the tag pointed to and a digest of every file the package contains. Commit it. Anyone who runs `pudu install` in a checkout of the project gets the same files, even if the tag has since been moved.

`deps/` holds the installed code. Do not commit it — `pudu init` adds it to `.gitignore` — and do not edit it: `pudu install` notices a changed file and puts the original back.

## Keeping it reproducible

| Command | Does |
| --- | --- |
| `pudu install` | installs exactly what `pudu.lock` names, writing the lock first if there is none |
| `pudu install --locked` | fails instead of changing `pudu.lock` — for continuous integration |
| `pudu install --offline` | uses only what is already downloaded, and fails rather than reaching the network |
| `pudu update [name]` | moves to the newest revision or release the manifest allows |
| `pudu uninstall <name>` | removes a dependency from the manifest, the lock, and `deps/` |
| `pudu deps` | lists the direct dependencies and what is locked for each |
| `pudu tree` | shows every package the project uses, and what uses it |

Downloads are kept in `~/.pudu/cache` (or `$PUDU_HOME/cache`) and shared by every project on the machine, so a second project using the same commit copies files and downloads nothing. With a lock present and the cache holding what it names, `pudu install` makes no network request and runs no git command, and `pudu check`, `run`, and `test` never touch the network. Repositories are fetched and packages copied side by side, and a package is copied again only if its files in `deps/` changed; a cached copy whose files no longer match `pudu.lock` is refused rather than installed.

## Publishing a package

A package is a GitHub repository: `@owner/repo` is `github.com/owner/repo`, and you publish it with the GitHub account that can push to it. Sign in once on each machine:

```sh
pudu login
```

`pudu login` prints `https://github.com/login/device` and a code; open the page, enter the code, and approve. Add `--private` to publish from private repositories. On a machine without a browser, such as CI, run `pudu login --token <GitHub token>` or set `PUDU_TOKEN`.

Name the package `@owner/repo` in `pudu.toml`, commit, and push to GitHub, then:

| Command | Does |
| --- | --- |
| `pudu push` | registers the project on the registry, or refreshes it, from the repository's default branch |
| `pudu release 1.2.0 --notes CHANGES.md` | checks the project, runs its tests, tags the commit `v1.2.0`, pushes the tag, and publishes it |
| `pudu logout` | forgets the token on this machine |

`pudu release` refuses a version that is not the one in `pudu.toml`, a working tree with changes not committed, a version already released, and one lower than a release on the same major line. The registry downloads the tagged commit from GitHub and keeps its own copy, so moving or deleting the tag later changes no one's build. A project from a private repository is private: only accounts that can read the repository see or install it.

## Choosing new versions

`pudu update` moves to the newest releases the requirements in `pudu.toml` accept, so it never crosses a major version. `pudu upgrade` rewrites each requirement to the newest release and names every package whose major version changed, with the address of its release notes.

A new resolution does not choose a release published in the last 72 hours: most poisoned releases are found and pulled within that time. A version already in `pudu.lock`, or one named exactly (`pudu install @alice/json-schema@1.4.3`), is always allowed. The age is set under `[install]`:

```toml
[install]
min-release-age = 24
registry = "https://packages.pudu-lang.org"
```

## Module roots

Each package owns one module root: `parser` owns `Parser` and every module beneath it. The root is the package's name in PascalCase unless its own `pudu.toml` sets `root`. Two packages in one program may not own the same root, and `pudu install` says which two collide before anything is changed:

```text
pudu install: clash and shapes-kit both own the module root ShapesKit; a program can use only one package for each root
```

`Std` belongs to the compiler. A package that ships a module under `Std` or `Core` is refused, so no dependency can quietly replace part of the standard library. A project may still shadow a standard module deliberately, in its own `src`, where a reader will see it.

## What installing never does

Installing a package copies files and checks their digests. It never runs anything the package contains: there are no install scripts, no build hooks, and no compilation step. A dependency can only do something when your program calls it.

One version of each package is used by the whole program. When two dependencies need versions that cannot both be met, `pudu install` names each requirement and who asked for it, rather than installing two copies whose types would not match.
