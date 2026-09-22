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
| `@alice/json-schema` | the project `json-schema` owned by the handle `alice`: the GitHub repository `github.com/alice/json-schema` |
| `@alice/json-schema@1.4.0` | exactly release 1.4.0 |
| `@alice/json-schema@^1.4` | the newest release compatible with 1.4 |

A handle is a GitHub user or organization and a project is one of its repositories: packages live
where their code already lives, and the registry keeps no accounts of its own. Handles and project
names are the GitHub names in lowercase, and must be lowercase ASCII letters, digits, and single
hyphens, 1 to 39 characters, not starting or ending with a hyphen; a repository whose name does not
fit cannot be published. `std`, `core`, `pudu`, and `admin` are reserved handles. A release version is Semantic Versioning 2.0.0 (`MAJOR.MINOR.PATCH`, optional pre-release).

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
dependencies = ["@bob/text"]

[[package]]
name = "parser"
version = "0.4.0"
source = "git+https://github.com/carol/parser#3b1e07c…"
checksum = "sha256:41aa…"
root = "Parser"
dependencies = []
```

A package's dependencies are listed by name; the version of each is in its own entry, since a
program holds one version of each package. Entries are sorted by name, fields are in a fixed order, and nothing in it depends on time or on the
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

1. the project's own source directory;
2. each path dependency, as today;
3. each installed package's source directory, `deps/<name>/<source>`;
4. for a `Std.*` module, the compiler's standard library.

Installed packages are never searched for a `Std.*` module. The project itself may still shadow one
deliberately, in its own tree where a reader sees it, as it always could; a dependency may not.

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
| `pudu login [--token T] [--registry URL]` | sign this machine in with GitHub |
| `pudu logout` | forget the stored token |
| `pudu whoami` | the GitHub account the stored token belongs to |
| `pudu push` | register the project, or refresh it from its repository's default branch |
| `pudu release <version> [--notes FILE]` | tag the commit on GitHub and publish it as an immutable release |

A `<spec>` is `@h/n`, `@h/n@<version or requirement>`, a path (`./x`, `../x`, `/x`), or a git URL
with an optional `#rev`. `--locked` refuses any change to `pudu.lock` (for CI); `--offline` refuses
the network and uses only the cache.

### Consumer path

```text
$ pudu install @alice/json-schema
Resolved 2 packages in 310ms · 2 fetched
Packages: +2
  + @alice/json-schema 1.4.2
  + @bob/text 0.6.0          (needed by @alice/json-schema)
Installed 2 packages into deps/ in 18ms
Wrote pudu.toml, pudu.lock

@alice/json-schema provides the modules under JsonSchema, such as:
  import JsonSchema.Validate

Done in 334ms
```

The import line tells the reader the module to import. While the command works, an interactive
terminal shows one live line on stderr — a spinner, the phase, counts fetched, from cache, copied,
and up to date, what is in flight, and the elapsed time — erased when the summary prints.
`--verbose` prints each step as a timed line; `--quiet` prints only errors. A log that is not a
terminal gets the summary alone.

Installing does each thing once: a locked commit already in the cache starts no git process, a
repository is fetched at most once per run, a checkout's tree digest is computed when it is written
and kept beside it, a copy hashes the bytes it writes, and an installed package is re-hashed only
when the sizes or modification times of its files changed. Repositories are fetched and packages
copied side by side, up to eight at a time.

### Publisher path

```text
$ pudu login
open https://github.com/login/device and enter the code WXYZ-2345
signed in as @alice

$ pudu push
registered @alice/json-schema from github.com/alice/json-schema — https://pudu-lang.org/@alice/json-schema

$ pudu release 1.4.3 --notes CHANGES.md
checked 12 modules, 40 tests passed
tagged v1.4.3 at 3b1e07c and pushed it to origin
released @alice/json-schema 1.4.3 — install with: pudu install @alice/json-schema@1.4.3
```

`pudu release` refuses if the manifest's `version` is not the version given, if the working tree has
changes not committed, or if the commit is not on the repository's remote. It checks the project,
runs its tests, creates the annotated tag `v<version>` with the notes, pushes it, and asks the
registry to publish it. The registry refuses if the token cannot push to the repository, if that
version exists, or if it is not greater than the latest release on the same major line.

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

GitHub is where a package's code and its owner live; the registry is where a release is kept once it
is published. To publish, the registry resolves the tag to its commit, downloads that commit's archive
from GitHub, applies the same refusals as for any archive, reads the `pudu.toml` inside it, and repacks
the package's files into its own canonical `.tar.gz` (sorted, time 0, mode 0644). The digest of that
archive is the release's checksum. Installs download the registry's copy, so a tag that is moved, or a
repository that is deleted or made private, changes no existing build.

### API

| Method and path | Answers |
| --- | --- |
| `GET /api/v1/packages?q=&page=` | projects matching a query, by name, handle, description, keywords |
| `GET /api/v1/packages/@h/n` | the project document: metadata, README, visibility, releases |
| `GET /api/v1/packages/@h/n/releases/<v>/archive` | the release archive, `application/gzip` |
| `GET /api/v1/packages/@h/n/releases/<v>/files/<path>` | one file of a release, for the source view |
| `GET /api/v1/handles/@h` | a handle's profile and public projects |
| `PUT /api/v1/packages/@h/n/head` | push: register the project and refresh it from the default branch (authenticated) |
| `POST /api/v1/packages/@h/n/releases` | release a tag as an immutable version: `{version, tag, notes}` (authenticated) |
| `PATCH /api/v1/packages/@h/n` | owner settings: description, visibility (authenticated) |
| `DELETE /api/v1/packages/@h/n` | delete a project with no releases, or unlist one that has them |
| `GET /api/v1/config` | what `pudu login` needs: the GitHub OAuth client id and GitHub's addresses |
| `GET /api/v1/whoami` | the GitHub account a token belongs to |

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

The registry has no accounts, passwords, or token secrets. A request is authenticated by a GitHub
token in `Authorization: Bearer`; the registry asks GitHub whose it is (`GET /user`) and caches the
answer by the token's digest for five minutes. Publishing `@owner/repo`, or changing its settings,
requires that the token can push to `github.com/owner/repo`, which covers users and organizations
alike. A handle's profile — display name, avatar, and GitHub address — is copied from GitHub when one
of its projects is registered or released.

`pudu login` runs GitHub's OAuth device flow with the client id the registry names at
`/api/v1/config`: it prints `https://github.com/login/device` and a code, polls GitHub until the person
approves, and stores the token in `$PUDU_HOME/credentials.toml` with owner-only permissions, per
registry, and never in a manifest or lock. The flow needs no client secret. `pudu login --token`
stores a token made elsewhere, and `PUDU_TOKEN` overrides the file, so CI can use the token its
workflow already has.

### Private projects

A project from a private repository is private. Its document, files, and archives are answered only
to a token that can read the repository; to anyone else it does not exist (404). Installing one
requires `pudu login` on that machine. The lock records the same checksum as for a public release, so
a private package is exactly as reproducible.

## Website

The package pages are part of the existing site: same masthead, typography, and code surfaces, with
an original Pudu banner and compact package list. They read the registry's documents at build time, the way `/download` reads the release
list, so a page answers from the CDN and never waits on the registry; a new release appears on the
next deployment, and the install command a page shows is always one the registry answers.

| Address | Shows |
| --- | --- |
| `/packages` | a catalog of public projects, with `@handle / name`, description, and latest version; keyword links filter the catalog, and its search form submits to `/packages/search?q=` |
| `/@h` | a handle's profile and its public projects |
| `/@h/n` | the project: a banner with identity, description, release, and **Install** disclosure; README as the landing content beside a sidebar with keywords, dependencies, and latest release |
| `/@h/n/source` | the latest release's files as a tree beside the selected file, with linkable source lines |
| `/@h/n/docs` | the API reference for the release, rendered from its generated catalogue in a package-specific reference view |
| `/@h/n/releases` | the latest release first with its notes and install command, then earlier releases |

The install disclosure starts with `pudu install @h/n@<latest>` so the selected release is available
even during the 72-hour minimum release age. The version picker rewrites that command; a separate
unversioned command follows the configured release-age policy. Copy buttons and a root-module import
line are provided. Projects with no non-yanked release have no install control. Owner settings remain
registry API operations paired with `pudu login`.

Project search on `/packages/search?q=` ranks exact names, then handles, then words in descriptions and
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

Package ecosystems are attacked through the tool, the registry, the lock, and the people who
publish. Each attack below has happened to a large ecosystem; each has a defense here that does not
depend on a reader noticing in time.

| Attack | How it worked elsewhere | Defense |
| --- | --- | --- |
| Code run at install | Worms spread through install hooks that read tokens from the machine and republished every package the victim owned | `pudu install` never executes anything a package contains: no hooks, no build scripts, no compile. Installing is copying verified files. |
| A malicious release installed within hours | A phished maintainer's account published poisoned versions of widely used packages; most were pulled within hours, after thousands of installs | A new resolution skips releases younger than the minimum release age (72 hours by default, `min-release-age` in `[install]`); a locked version is unaffected. `pudu install @h/n@1.2.3` names a fresh release deliberately and says how old it is. |
| Account takeover and stolen tokens | Phishing for second-factor resets; tokens harvested from CI | Accounts are GitHub accounts, so their second factor and token scopes are GitHub's; the registry stores no secret at all; tokens are kept with owner-only permissions on disk; a release records the account that published it and the commit it came from. |
| Dependency confusion | A public package with a private package's name and a higher version was chosen | A package is `@handle/name` on one registry; the lock records the registry each release came from, and a registry package is never looked for anywhere else. |
| Manifest confusion | The metadata a registry showed differed from the manifest inside the archive | The registry derives a release's version, dependencies, and root from the `pudu.toml` inside the archive; the client compares the unpacked manifest with the release document and refuses a difference. |
| Lock injection | A lock edited in a change pointed a dependency at another URL, unreviewed | The manifest says where each package comes from; the lock only records what was chosen there. A lock entry whose source does not match the manifest's is not used, and a registry release whose digest differs from the lock's is refused. |
| Typosquatting and invented names | Look-alike names, and names an assistant made up and someone then registered | Names are scoped by handle; installing a name that does not exist fails with the closest real names; the install report shows the publisher, the release's age, and whether the project is new; the registry refuses a new project whose name is one edit from an established one owned by another handle. |
| Maintainer handoff | A tired maintainer gave a package to a stranger, who added a malicious dependency | Every release records its publisher; `pudu update` and `pudu upgrade` say when a package's publisher changed and when a release adds a dependency. |
| Unpublishing | A deleted package broke every build that used it | Releases are immutable and cannot be deleted, only yanked; a yanked release still installs from an existing lock. |
| Moved tags and branches | A tag was moved to different code | A git dependency is locked to a commit and checked by tree digest. |
| Malicious archives | Path traversal and decompression bombs | Unpacking refuses absolute paths, `..`, links, device files, duplicate paths, and archives over size and file-count limits, and the digest is checked before unpacking. |
| Interception | A download replaced in transit | Registry traffic is HTTPS only (plain HTTP only for `localhost`); the lock's digest, not the connection, is what proves the content. |

Beyond these: with a lock present, builds make no network request, and `--offline` guarantees it; a
package may not own `Std` or `Core`; and a program can be run with `pudu run --confined`, which
refuses files, network, and foreign calls to code that should not need them.

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
- **Root ownership across the registry.** Roots are unique per program, not per registry. Reserving a
  root registry-wide on first release would prevent most conflicts before they reach a program, at
  the cost of first-come names.
- **Favourites, tickets, contributions.** Not in the first release of the website pages.

## Grill Log

- **Q:** Registry accounts, or GitHub's? **A:** GitHub's, for identity and for source. _Rationale:_ the
  code already lives there, a handle means the same owner in both places, and the registry then holds
  no passwords or token secrets. _Rejected:_ registry passwords and its own device pairing.
- **Q:** Install straight from GitHub tags? **A:** No; from the registry's copy of the tagged commit.
  _Rationale:_ a tag can be moved and a repository deleted, and neither may change or break a locked
  build. _Rejected:_ an index that only records checksums.

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
