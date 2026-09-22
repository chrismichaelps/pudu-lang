---
type: architecture
status: ACTIVE
tags: [architecture, packages, tooling, registry, website]
aliases: [Package System]
---

# Package System

## Purpose

Let a Pudu program use another person's code with one command, reproducibly, without a second tool.
A project names what it depends on in `pudu.toml`; `pudu.lock` records exactly what was chosen and
the digest of its content; `deps/` holds the chosen code where the compiler, the language server, and
a reader can all see it. A public registry hosts projects under `@handle/name`, and the website lets a
reader find one, read it, and copy the command that installs it.

Everything is in the `pudu` executable. Nothing a dependency contains runs during installation, and
nothing a dependency contains can replace the standard library.

## What the design is honest about

Pudu is a language of text files and modules. A module's name is its path under a source directory,
imports are absolute, and a public type is identified by the module that declares it. So:

- A package is a directory of modules, published as an immutable archive of files. There is no
  database of definitions and no hash per definition; the unit of identity and of integrity is the
  package release.
- One version of a package per program. Two versions of one package would declare the same module
  names twice, and a type from one would be a different type from the other while reading
  identically. Resolution picks one version per package for the whole graph and says so when that is
  impossible.
- A package owns a module root. `@alice/json-schema` owns `JsonSchema.*` (or the root its manifest
  names). Two packages in one program may not own the same root; the conflict is reported before
  anything is compiled.
- `Std` and `Core` belong to the compiler. A package may not declare either root or ship a file
  under them.

## Identity

| Written | Means |
| --- | --- |
| `@alice/json-schema` | the project `json-schema` owned by the handle `alice` |
| `@alice/json-schema@1.4.0` | exactly release 1.4.0 |
| `@alice/json-schema@^1.4` | the newest release compatible with 1.4 |

Handles and project names use lowercase ASCII letters, digits, and single hyphens, 1 to 39
characters, and may not start or end with a hyphen. `std`, `core`, `pudu`, and `admin` are reserved
handles. A release version is Semantic Versioning 2.0.0 (`MAJOR.MINOR.PATCH`, optional pre-release).

The module root a package owns is the manifest's `root`, or the PascalCase of the project name:
`json-schema` → `JsonSchema`. The root must be a valid module segment and must not be `Std` or
`Core`.

## Project layout

```text
my-app/
  pudu.toml          what the project is and what it depends on — written by people
  pudu.lock          what was chosen, and the digest of each — written by pudu, committed
  src/               the project's own modules
    Main.pudu
  test/
  deps/              installed packages — written by pudu, not committed
    @alice/
      json-schema/   one release, exactly as published
        pudu.toml
        src/JsonSchema.pudu
    parser/          a git dependency, by its local name
```

`deps/` is to installed code what `pudu.lock` is to installed versions: generated, complete, and
reproducible from the lock and the cache. `pudu init` writes a `.gitignore` naming it. A reader, the
compiler, and the language server all read installed code there, so go-to-definition lands in a
readable file rather than a cache path.

The download cache is shared by every project on the machine: `$PUDU_HOME/cache/` (default
`~/.pudu/cache/`), holding archives by digest (`sha256-<hex>.tar.gz`) and git checkouts by commit.
A second project installing the same release copies from the cache and makes no request.

## Manifest: `pudu.toml`

```toml
[package]
name = "@alice/report"          # the project's identity; a bare name is fine until it is published
version = "0.3.0"
description = "Monthly reports from a ledger"
license = "MIT"
keywords = ["reports", "ledger"]
language = ">=0.1.0 <0.2.0"      # the Pudu versions it works with
source = "src"                   # where its modules are
root = "Report"                  # the module root it owns; default from the name

[dependencies]
"@alice/json-schema" = "^1.4"                            # a registry release
"@bob/decimal-format" = "=2.0.1"
geometry = { path = "../geometry" }                       # a directory on this machine
parser = { git = "https://github.com/carol/parser", rev = "v0.4.0" }
```

TOML, because it is what the manifest already is, what configuration in the standard library already
reads, and a format people edit by hand without quoting surprises. Unknown keys are kept and
ignored, so a manifest can carry what a project needs.

Requirements follow the common conventions:

| Requirement | Accepts |
| --- | --- |
| `"1.4.2"` or `"^1.4.2"` | `>=1.4.2, <2.0.0` (for `0.x`, `<0.(x+1).0`) |
| `"~1.4.2"` | `>=1.4.2, <1.5.0` |
| `"=1.4.2"` | exactly 1.4.2 |
| `">=1.2, <1.8"` | the range written |
| `"*"` | any release |

A pre-release is selected only when a requirement names one.

Earlier manifests keep working: `name = "shapes"` without a handle, and `dependency = "../dir"` as a
bare path, which names a directory of modules exactly as before.

## Lock: `pudu.lock`

```toml
# Written by pudu install. Do not edit by hand.
version = 1

[[package]]
name = "@alice/json-schema"
version = "1.4.2"
source = "registry+https://packages.pudu-lang.org"
checksum = "sha256:9f2c…"
root = "JsonSchema"
dependencies = ["@bob/text@0.6.0"]

[[package]]
name = "parser"
version = "0.4.0"
source = "git+https://github.com/carol/parser#3b1e07c…"
checksum = "sha256:41aa…"
root = "Parser"
dependencies = []
```

Entries are sorted by name, fields are in a fixed order, and nothing in it depends on time or on the
machine, so the same graph writes the same bytes and a change to it reads as a change in review.

- A registry release's checksum is the SHA-256 of its archive, as published. A downloaded archive
  whose digest differs is refused before it is unpacked.
- A git dependency is locked to a commit, never a branch or tag; its checksum is the tree digest of
  the files it contributes.
- A path dependency is not locked: it is the code on this machine, used as it is.

The tree digest of a directory is the SHA-256 of its sorted listing, one line per file:
`<relative path> NUL <size> NUL <sha256 of content> LF`. It is how `deps/` is checked against the
lock: an edited installed file is reported and restored by `pudu install`.

When a lock is present and satisfies the manifest, `pudu install` makes no network request for
anything already in the cache. `pudu check`, `run`, `test`, and the language server never make one.

## Module resolution

The program graph searches, in order:

1. the compiler's `Std.*` and `Core.*`, which nothing replaces;
2. the project's own source directory;
3. each path dependency, as today;
4. each installed package's source directory, `deps/<name>/<source>`.

A package whose root is claimed by the project itself or by another package is a conflict, reported
at `pudu install` with both owners named. A module file under `Std/` or `Core/` inside a package is
refused at install. A module a package ships outside its root is allowed but reported as a warning
at publish time, because it cannot be told apart from another package's.

`pudu check` compares `deps/` with `pudu.lock` before compiling and says which command fixes a
difference (`pudu install`), instead of reporting a missing module.

## Commands

All in `pudu`:

| Command | Does |
| --- | --- |
| `pudu init [dir] [--name @h/n]` | create a project, its manifest, `src/Main.pudu`, and `.gitignore` |
| `pudu install` | install exactly what `pudu.lock` names; resolve and write the lock if there is none |
| `pudu install <spec>…` | add dependencies, resolve, lock, and install |
| `pudu uninstall <name>…` | remove dependencies from the manifest, the lock, and `deps/` |
| `pudu update [name…]` | move to the newest releases the manifest's requirements allow |
| `pudu upgrade [name…]` | raise requirements to the latest releases, naming every major version crossed |
| `pudu deps` | the direct dependencies, their requirements, and what is locked |
| `pudu tree` | the whole resolved graph |
| `pudu login [--registry URL]` | pair this machine with a registry account |
| `pudu logout` | forget the stored token |
| `pudu push` | upload the project's current code as its latest unreleased snapshot |
| `pudu release <version> [--notes FILE]` | publish an immutable release |

A `<spec>` is `@h/n`, `@h/n@<version or requirement>`, a path (`./x`, `../x`, `/x`), or a git URL
with an optional `#rev`. `--locked` refuses any change to `pudu.lock` (for CI); `--offline` refuses
the network and uses only the cache.

### Consumer path

```text
$ pudu install @alice/json-schema
resolving @alice/json-schema (latest: 1.4.2)
  + @alice/json-schema 1.4.2
  + @bob/text 0.6.0          (needed by @alice/json-schema)
wrote pudu.toml, pudu.lock
installed 2 packages into deps/

import JsonSchema.Validate
```

The last line tells the reader the module to import.

### Publisher path

```text
$ pudu login
open https://pudu-lang.org/login/device and enter the code WXYZ-2345
signed in as @alice

$ pudu push
pushed @alice/json-schema (12 modules, 38 KB) — https://pudu-lang.org/@alice/json-schema

$ pudu release 1.4.3 --notes CHANGES.md
checked 12 modules, 40 tests passed
released @alice/json-schema 1.4.3 — install with: pudu install @alice/json-schema@1.4.3
```

`pudu release` checks the project and runs its tests before uploading, and refuses if the manifest's
`version` is not the version given, if that version exists, or if it is not greater than the latest
release on the same major line.

### Errors worth their own words

Every failure names the manifest line or the requirement chain that caused it:

- **No such project:** `@alice/json-shema is not a project on packages.pudu-lang.org — did you mean
  @alice/json-schema?`
- **Conflict:** `@bob/text` is required at `^0.6` by `@alice/json-schema 1.4.2` and at `^0.7` by the
  project's own `pudu.toml:9`; no release satisfies both.
- **Root taken:** `@carol/json` and `@alice/json-schema` both own the module root `Json`; a program
  can use one of them.
- **Integrity:** the archive downloaded for `@alice/json-schema 1.4.2` has digest `sha256:1a…`, and
  `pudu.lock` records `sha256:9f…`. Nothing was installed.
- **Locked:** `--locked` was given and `pudu.toml` asks for `@bob/text ^0.7`, which the lock does
  not satisfy; run `pudu install` without `--locked` to update it.
- **Offline:** `@alice/json-schema 1.4.2` is not in the cache and `--offline` was given.
- **Reserved:** a package may not own `Std`; rename the root in `pudu.toml`.

Diagnostics use the `E7xxx` range with the manifest or lock line as their span when there is one.

## Registry

The registry is a Pudu program (`registry/`) that keeps its data in a directory, answers the API
below, and stores each release's archive once, by digest. Its read side is plain files by design: a
project document and the archives are immutable per release, so any static host or CDN can serve
them.

### API

| Method and path | Answers |
| --- | --- |
| `GET /api/v1/packages?q=&page=` | projects matching a query, by name, handle, description, keywords |
| `GET /api/v1/packages/@h/n` | the project document: metadata, README, visibility, releases |
| `GET /api/v1/packages/@h/n/releases/<v>/archive` | the release archive, `application/gzip` |
| `GET /api/v1/packages/@h/n/releases/<v>/files/<path>` | one file of a release, for the source view |
| `GET /api/v1/handles/@h` | a handle's profile and public projects |
| `PUT /api/v1/packages/@h/n/head` | push: the project's latest snapshot (authenticated) |
| `POST /api/v1/packages/@h/n/releases` | release: an immutable version (authenticated) |
| `PATCH /api/v1/packages/@h/n` | owner settings: description, visibility (authenticated) |
| `DELETE /api/v1/packages/@h/n` | delete a project with no releases, or unlist one that has them |
| `POST /api/v1/login/device` | begin pairing: a user code and a device code |
| `POST /api/v1/login/device/token` | the CLI polls with the device code until approved |
| `GET /api/v1/whoami` | the handle a token belongs to |

A project document:

```json
{
  "name": "@alice/json-schema",
  "description": "Validate JSON against a schema",
  "keywords": ["json", "schema"],
  "license": "MIT",
  "visibility": "public",
  "root": "JsonSchema",
  "readme": "# JSON Schema\n…",
  "latest": "1.4.2",
  "releases": [
    {
      "version": "1.4.2",
      "publishedAt": "2026-09-22T14:03:11Z",
      "checksum": "sha256:9f2c…",
      "size": 38112,
      "language": ">=0.1.0 <0.2.0",
      "dependencies": { "@bob/text": "^0.6" },
      "modules": ["JsonSchema", "JsonSchema.Validate"],
      "notes": "Faster validation of large arrays."
    }
  ]
}
```

A release is immutable: its archive, digest, dependencies, and notes never change. A release can be
yanked, which keeps it installable from an existing lock and stops new resolutions choosing it.

### Accounts and tokens

`pudu login` starts device pairing: the CLI receives a short user code and a URL, the person signs in
on the website and approves the code, and the CLI receives a token. The token is stored in
`$PUDU_HOME/credentials.toml` with owner-only permissions, per registry, and never in a manifest or
lock. The registry stores only a digest of each token. `pudu login --token` accepts a token made on
the website for machines without a browser, such as CI.

### Private projects

A private project's document, files, and archives are answered only to its owner's token; to anyone
else it does not exist (404). Installing one requires `pudu login` on that machine. The lock records
the same checksum as for a public release, so a private package is exactly as reproducible.

## Website

The package pages are part of the existing site: same masthead, typography, cards, and code
surfaces. They read the registry's documents at build time, the way `/download` reads the release
list, so a page answers from the CDN and never waits on the registry; a new release appears on the
next deployment, and the install command a page shows is always one the registry answers.

| Address | Shows |
| --- | --- |
| `/packages` | search and the catalog: featured projects and projects by keyword, each a card with `@handle / name`, description, latest version, and an Install button |
| `/@h` | a handle's profile and its public projects |
| `/@h/n` | the project: README as the landing content; a sidebar with description, keywords, dependencies, and latest release; **Install** opening the install dialog |
| `/@h/n/source` | the latest release's modules as a tree beside the selected file, each declaration linkable |
| `/@h/n/docs` | the API reference for the release, rendered by the same views as the standard library's |
| `/@h/n/releases` | the latest release first with its notes and install command, then earlier releases |

The install dialog shows `pudu install @h/n` for the latest release, a version picker that rewrites
the command, a copy button, and the import line for the package's root module. Owners' settings
(visibility, description, deletion) live on the registry's account pages, which pair with
`pudu login`.

Project search on `/packages` ranks exact names, then handles, then words in descriptions and
keywords. Declarations across public packages join the site's existing API search once packages
carry the same documentation catalogue `pudu doc --json` produces for the standard library.

The full package UI ships when install, resolve, lock, push, release, and a hosted public registry
are production-ready. Until then the site shows no package pages.

## Upgrades

`pudu update` stays within the manifest's requirements, so it never takes a new major version.
`pudu upgrade` rewrites the requirements to the latest releases and lists each package whose major
version changed with a link to its release notes. After either command `pudu check` runs over the
project, so a breaking change is reported as the compile errors it causes, in the project's own
files. Two versions of one package never coexist; a project needing both is told which requirement
chains disagree.

## Security

- Nothing a dependency contains is executed by `pudu install`: no scripts, no hooks.
- Archives are verified against the lock's digest before they are unpacked, and unpacking refuses
  absolute paths, `..`, links, device files, duplicate paths, and archives above size and file-count
  limits.
- With a lock present, builds make no network request, and `--offline` makes that a guarantee.
- Registry transport is HTTPS with the system trust store; the digest, not the connection, is what
  proves the content.
- Tokens are stored per registry with owner-only permissions and are sent only to the registry they
  were issued by.
- A git dependency is locked to a commit and checked by tree digest, so a moved tag changes nothing
  until `pudu update` is run and reviewed.

## Migration

A project with no manifest keeps compiling as a single file or a directory of modules. A manifest
with path dependencies keeps its meaning. `pudu install` on such a project writes a lock with no
entries and changes nothing else. Moving a local directory to the registry is `pudu push` and
`pudu release` in the dependency, then `pudu install @h/n` in the dependent, which replaces the path
entry.

## Phases

1. **Local:** manifest with registry, path, and git dependencies; `pudu.lock`; `deps/`; tree digests;
   resolution into the program graph; `init`, `install`, `uninstall`, `update`, `deps`, `tree` over
   path and git sources; root and `Std` protection; `--locked` and `--offline`.
2. **Registry:** the registry program and its API; `install @h/n` with the requirement solver and the
   cache; `login`, `push`, `release`, `upgrade`; private projects.
3. **Hardening:** archive limits and traversal tests, integrity failures, atomic lock and `deps/`
   updates, deterministic lock snapshots, a local registry conformance suite, repeated
   clean/locked/offline builds producing the same program.
4. **Website:** catalog, handle, project, source, docs, releases, the install dialog, and project
   search, built from registry documents — shipped when 1–3 hold against a hosted registry.

## Open decisions

- **Hosting the registry.** The website runs on a platform with no disk. The registry needs one
  persistent volume (or an object store and a small database). Where it runs, and its domain, is an
  operator's decision; nothing in the design depends on the choice.
- **Sign-in on the website.** Device pairing needs the site to know who a person is. An account
  with a password on the registry works with no third party; signing in with a code host's account
  is friendlier and needs an OAuth application.
- **Root ownership across the registry.** Roots are unique per program, not per registry. Reserving a
  root registry-wide on first release would prevent most conflicts before they reach a program, at
  the cost of first-come names.
- **Favourites, tickets, contributions.** Not in the first release of the website pages.

## Grill Log

- **Q:** Allow arbitrary install or build scripts? **A:** No. _Rationale:_ they execute dependency code
  before the project is built and turn resolution into remote code execution. _Rejected:_ lifecycle
  hooks.
- **Q:** Resolve several versions of one package simultaneously? **A:** No. _Rationale:_ module and
  nominal identity carry no package qualifier; two copies would alias distinct public types.
  _Rejected:_ basename deduplication; whichever version resolves first.
- **Q:** Keep installed code in a global cache only? **A:** No; install into `deps/`. _Rationale:_ the
  compiler, the language server, and a reader should all find a dependency's source in the project,
  and a project folder that can be zipped with its dependencies is easy to reason about.
  _Rejected:_ search roots pointing into a cache directory named by digests.
- **Q:** Namespace modules by handle (`Alice.JsonSchema.*`)? **A:** No. _Rationale:_ imports would
  change when a project moves between handles, and the common case — one package per root — reads
  better without it. Conflicts are rare and reported precisely. _Rejected:_ handle-prefixed roots.
- **Q:** Trust TLS without checksums? **A:** No. _Rationale:_ TLS authenticates the endpoint; the lock
  authenticates the content chosen for this graph. _Rejected:_ checksums kept only in the cache.
- **Q:** Let a package replace `Std`? **A:** No. _Rationale:_ the standard library is versioned with
  the compiler. _Rejected:_ dependency precedence over distribution modules.
- **Q:** Lock a git dependency to a tag? **A:** No, to a commit. _Rationale:_ a tag can be moved.
  _Rejected:_ branch and tag pins.
- **Q:** Render package pages per request from the registry? **A:** No, at build time. _Rationale:_ the
  site is static and answers from a CDN; a registry outage must not take package pages down.
  _Rejected:_ a live proxy in the site's function.

## Referenced by

[[architecture/_MOC]] · [[Engineering Delivery]] · [[Compiler Program]] · [[Compiler Library]] · [[Pudu CLI]]
