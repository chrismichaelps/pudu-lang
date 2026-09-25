# Dependencies

A project uses code other people wrote by naming it in `pudu.toml` and running `pudu install`. The command chooses a version of everything needed, records the choice and a digest of its content in `pudu.lock`, and puts the code in `deps/`, where the compiler, the editor, and you can all read it. There is no second tool: every command on this page is part of `pudu`.

## Installing a dependency

Name what you want to install: a package from GitHub, a directory on your machine, or a git repository at a tag, branch, or commit:

```sh
pudu install @alice/json-schema
pudu install @alice/json-schema@1.4.2
pudu install ../geometry
pudu install https://github.com/carol/parser.git#v0.4.0
```

A package is `@owner/repo`, the GitHub repository `github.com/owner/repo`, and its releases are its version tags (`v1.4.2`). Without a version, `pudu install` takes the newest release and writes a requirement compatible with it (`^1.4.2`); with `@1.4.2` it takes exactly that release.

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

A package is a GitHub repository with a `pudu.toml` naming it `@owner/repo`. There is no separate registry to sign up for: a release is a version tag, and the package is listed once the repository carries the topic `pudu-package`.

Commit and push the project to GitHub, then:

```sh
pudu login
pudu release 1.2.0 --notes CHANGES.md
```

`pudu login` stores a GitHub token. It takes the one the GitHub CLI already has (`gh auth login`), or one given with `pudu login --token <token>`; CI can set `PUDU_TOKEN` instead. `pudu release` checks the project, runs its tests, tags the commit `v1.2.0`, and pushes the tag — the release exists from that moment. With a token it also creates the GitHub release with your notes and adds the `pudu-package` topic, which is what lists the package in `pudu search` and on the website.

| Command | Does |
| --- | --- |
| `pudu release 1.2.0 --notes CHANGES.md` | checks, tests, tags `v1.2.0`, pushes it, and publishes the GitHub release |
| `pudu search json` | lists packages on GitHub |
| `pudu logout` | forgets the token on this machine |

`pudu release` refuses a version that is not the one in `pudu.toml` and a working tree with changes not committed. Installing locks the commit the tag named and a digest of its files, so moving or deleting the tag later changes no locked build. A private repository's packages install for anyone git can authenticate to it.

## Choosing new versions

`pudu update` moves to the newest releases the requirements in `pudu.toml` accept, so it never crosses a major version. `pudu upgrade` rewrites each requirement to the newest release and names every package whose major version changed, with the address of its release notes.

A new resolution does not choose a release published in the last 72 hours: most poisoned releases are found and pulled within that time. A version already in `pudu.lock`, or one named exactly (`pudu install @alice/json-schema@1.4.3`), is always allowed. The age is set under `[install]`:

```toml
[install]
min-release-age = 24
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
