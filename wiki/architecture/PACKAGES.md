---
type: architecture
status: ACTIVE
tags: [architecture, packages, tooling, github, website]
aliases: [Package System]
---

# Package System

## Purpose

Let a Pudu program use another person's code with one command, reproducibly, without a second tool.
A project names what it depends on in `pudu.toml`; `pudu.lock` records exactly what was chosen and
the digest of its content; `deps/` holds the chosen code where the compiler, the language server, and
a reader can all see it. GitHub hosts every package as the repository `@owner/repo` names, and the website lets a
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
where their code already lives, and Pudu runs no service and keeps no accounts of its own. Handles and project
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
"@alice/json-schema" = "^1.4"                            # a package: github.com/alice/json-schema
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
source = "github+https://github.com/alice/json-schema#9d0e4b1…"
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

- A package release is locked to the commit its tag named when it was chosen, from the repository the
  name denotes; its checksum is the tree digest of the files it contributes. A tag moved later changes
  nothing that is locked, and copied files whose digest differs from the lock are refused.
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
at publish time, because it cannot be told apart from another package's: `pudu release` names each
such file under `source`, except an executable entry `Main.pudu` beside the root.

`pudu check` compares `deps/` with `pudu.lock` before compiling and says which command fixes a
difference (`pudu install`), instead of reporting a missing module.

## Commands

All in `pudu`:

| Command | Does |
| --- | --- |
| `pudu init [dir] [--name @h/n] [--lib]` | create an application with `src/Main.pudu` or a library under its package root, plus manifest, test, README, and `.gitignore` |
| `pudu install` | install exactly what `pudu.lock` names; resolve and write the lock if there is none |
| `pudu install <spec>…` | add dependencies, resolve, lock, and install |
| `pudu uninstall <name>…` | remove dependencies from the manifest, the lock, and `deps/` |
| `pudu update [name…]` | move to the newest releases the manifest's requirements allow |
| `pudu upgrade [name…]` | raise requirements to the latest releases, naming every major version crossed |
| `pudu deps` | the direct dependencies, their requirements, and what is locked |
| `pudu tree` | the whole resolved graph |
| `pudu login [--token T] [--private]` | store a GitHub token on this machine |
| `pudu logout` | forget the stored token |
| `pudu whoami` | the GitHub account the stored token belongs to |
| `pudu search [words…]` | packages on GitHub: repositories with the `pudu-package` topic |
| `pudu release <version> [--notes FILE]` | check, test, tag `v<version>`, push it, and publish the GitHub release |

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
signed in to GitHub as @alice

$ pudu release 1.4.3 --notes CHANGES.md
checked 12 modules
tagged v1.4.3 at 3b1e07c and pushed it to origin
created the GitHub release v1.4.3
added the pudu-package topic, which lists the package
released @alice/json-schema 1.4.3 — install with: pudu install @alice/json-schema@1.4.3
```

`pudu release` refuses if the manifest's `version` is not the version given or the working tree has
changes not committed. It checks the project, runs its tests, creates the annotated tag `v<version>`
(reusing one already on this commit, refusing one on another), and pushes it: from that moment the
release exists, because a release is a tag. With a token it also creates the GitHub release with the
notes and adds the `pudu-package` topic; either failing is reported and leaves the release standing.

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

## GitHub is the index

Pudu runs no package service and keeps no database. Every question a package manager asks is
answered by git or by GitHub:

| Question | Answered by |
| --- | --- |
| Which packages exist? | GitHub search: repositories with the topic `pudu-package` |
| Where is `@owner/repo`? | `https://github.com/owner/repo` (`PUDU_GITHUB_URL` for another host) |
| Which releases does it have? | its tags that read as versions, `v1.4.2` or `1.4.2`, as `git ls-remote` lists them |
| What does a release need? | the `pudu.toml` at the tag, read from the machine's bare clone |
| When was it released? | the tag's time, for the minimum release age |
| What are its notes? | the GitHub release of the tag, when there is one |
| Who may publish? | whoever can push a tag to the repository |
| Who can install a private package? | whoever git can authenticate to the repository |

A tag is a release of `@owner/repo` only when the `pudu.toml` at it names `@owner/repo` and gives the
tag's version, so a stray tag or a fork's manifest is never chosen. The solver asks for releases once
per package per run; the tag list, peeled commits, and times come from one `git for-each-ref`, and the
manifests at every tag from one `git cat-file --batch`. `git ls-remote` bounds the list to tags that
still exist, so a deleted tag stops being chosen; its commit stays in the bare clone, where a lock that
names it still installs. A locked version keeps its locked commit even when its tag has moved.

Without the network (`--offline`) or when a package's locked version is already in the bare clone,
nothing is fetched. `git` runs with prompts disabled, so a repository needing credentials fails with
git's reason rather than waiting on a terminal; private repositories use the machine's git
credentials, as `git clone` would.

### Tokens

A GitHub token is only needed to publish the GitHub release and add the topic, and to raise the API's
rate limit for `pudu search`. `pudu login` stores one in `$PUDU_HOME/credentials.toml` with owner-only
permissions: from `--token`; from GitHub's OAuth device flow when `PUDU_GITHUB_CLIENT_ID` names an
OAuth application; otherwise from the GitHub CLI (`gh auth token`). `PUDU_TOKEN` overrides the file,
so CI can use its own. The API is `PUDU_GITHUB_API`, or `https://api.github.com`.

## Website

The package pages are part of the existing site: same masthead, typography, and code surfaces, with
an original Pudu banner and dense, linked package rows. Package search shows matching projects and
public declarations from their generated API catalogues in a focused result panel. They are built from the GitHub API at deploy time
(`website/scripts/generate-packages.mjs`: search by topic, tags, releases, `pudu.toml` at each tag, the
latest release's archive), the way `/download` reads the release list, so a page answers from the CDN
and never waits on GitHub; a new release appears on the next deployment.

Discovery reads GitHub's topic index (`topic:pudu-package`); it never scans repositories. Because one
search returns at most 1,000 results, the generator splits the query by creation date until each
slice fits ([[Package topic discovery]]). Builds are incremental ([[Package snapshot cache]]):
- API reads are conditional, and an unchanged answer (`304`) costs no rate limit.
- Each tag commit's manifest is read once.
- A package whose tags and GitHub releases are unchanged carries its files and API catalogue forward
  with no archive download; only its live counts and discussions are re-read.

When the remaining rate limit falls to a reserve, changed packages keep their previous entry and are
refreshed by the next build rather than failing it.

The snapshot is the baseline, not the ceiling (#367). The serverless function lays a cached GitHub
overlay on it ([[website Service LivePackages]]): one topic search sorted by update finds packages
published since the build, admitted by the same tag-and-manifest rule, and refreshes counts and
newer releases of known ones. The listing, search, suggestions, and new packages' pages answer from
that overlay behind an edge cache (`s-maxage` with `stale-while-revalidate`), so a new package
appears within minutes without a deployment. Readers cause at most one GitHub refresh per freshness
window per function instance; a GitHub failure serves the remembered answer or the snapshot.
Known packages' own pages stay static until the next build.

| Address | Shows |
| --- | --- |
| `/packages` | a ledger of public projects (owner mark, `@handle / name`, description, latest release, stars) beside topic links with counts; its search box suggests from `/packages/suggest` and submits to `/packages/search?q=` |
| `/@h` | a handle's profile and its public projects |
| `/@h/n` | the project: a banner with identity, description, release, and **Install** disclosure; README as the landing content beside a sidebar with keywords, dependencies, and latest release |
| `/@h/n/source` | the latest release's files as a tree beside the selected file, with linkable source lines |
| `/@h/n/docs` | the API reference for the release, rendered from its generated catalogue in a package-specific reference view |
| `/@h/n/releases` | the latest release first with its notes and install command, then earlier releases |
| `/@h/n/tickets` and `/@h/n/tickets/:number` | recent public GitHub issues, then one issue's title, state, labels, author, date, and body |
| `/@h/n/contributions` and `/@h/n/contributions/:number` | recent public pull requests, then one contribution's title, review state, author, date, and body |

The install disclosure starts with `pudu install @h/n@<latest>` so the selected release is available
even during the 72-hour minimum release age. The version picker rewrites that command; a separate
unversioned command follows the configured release-age policy. Copy buttons and a root-module import
line are provided. Projects with no release have no install control. The project tabs show tickets
and contributions natively from a bounded build-time GitHub snapshot; new posts, review, and replies
continue on GitHub. Stars still link to the repository's GitHub stargazers.

Every package search box (catalogue, results page, and each project page) accepts four query forms:
`@owner`, `@owner/prefix`, a declaration name or qualified name, and a signature shape such as
`Str -> Int` or `Array Value`. `/packages/search?q=&filter=` renders the full results on the server:
matching projects, then public declarations from each project's generated API catalogue, each linked
to the package Docs section, so the page works without client JavaScript. `GET /packages/suggest`
answers the box under each field with bounded JSON (3 owners, 5 projects, 8 declarations, plus
totals). One service ranks both, so the box and the page agree. A `filter` names one project and
searches inside it: no project rows, declarations from that project only, and with an empty query
the project's declarations in order. A project page's own box is fixed to that project. The dynamic
function receives compact declaration facts in `packages.json` and serves both routes; it does not
need full API catalogue files.
The static snapshot keeps recent ticket and contribution bodies in separate per-project documents.
The dynamic search loader reads only the compact project index, while the full loader requires
release files and reads the discussion documents for static pages.
Long package, handle, search, ticket, and contribution lists render a bounded first page and
address subsequent pages by stable URLs. A small script fetches the next page near the scroll edge
and appends its rows; the same next-page link remains usable without JavaScript. Each request
contains only one page's rows. Search results use query pagination in the dynamic function.
Source tree file icons are local assets mapped by file extension, including the Pudu VS Code icon.
Data lists expose three clear states: a visible loading status while another page is requested,
an explanatory empty banner when no records match, and a loaded list. The next-page link stays
usable while loading or after a failed request. Missing pages use the shared reading-page banner.

`/packages` always answers and the masthead links it. Before a snapshot holds any project, it shows
how to publish the first one; project, handle, source, docs, and release pages exist for each project
the snapshot holds. The home page opens with the same banner as the catalogue and features up to six
packages when there are any.

## Upgrades

`pudu update` stays within the manifest's requirements, so it never takes a new major version.
`pudu upgrade` rewrites the requirements to the latest releases and lists each package whose major
version changed with a link to its release notes. After either command `pudu check` runs over the
project, so a breaking change is reported as the compile errors it causes, in the project's own
files. Two versions of one package never coexist; a project needing both is told which requirement
chains disagree.

## Security

Package ecosystems are attacked through the tool, the index, the lock, and the people who
publish. Each attack below has happened to a large ecosystem; each has a defense here that does not
depend on a reader noticing in time.

| Attack | How it worked elsewhere | Defense |
| --- | --- | --- |
| Code run at install | Worms spread through install hooks that read tokens from the machine and republished every package the victim owned | `pudu install` never executes anything a package contains: no hooks, no build scripts, no compile. Installing is copying verified files. |
| A malicious release installed within hours | A phished maintainer's account published poisoned versions of widely used packages; most were pulled within hours, after thousands of installs | A new resolution skips releases younger than the minimum release age (72 hours by default, `min-release-age` in `[install]`); a locked version is unaffected. `pudu install @h/n@1.2.3` names a fresh release deliberately and says how old it is. |
| Account takeover and stolen tokens | Phishing for second-factor resets; tokens harvested from CI | Accounts are GitHub accounts, so their second factor and token scopes are GitHub's; Pudu stores no secret anywhere but the owner-only credentials file; a lock records the commit each package came from. |
| Dependency confusion | A public package with a private package's name and a higher version was chosen | `@owner/repo` names exactly one repository; there is no second place to look it up. |
| Manifest confusion | The metadata shown differed from the manifest inside the archive | A release's version, dependencies, and root are read from the `pudu.toml` at its tag, which must name the package and the tag's version. |
| Lock injection | A lock edited in a change pointed a dependency at another URL, unreviewed | The manifest says where each package comes from; the lock only records what was chosen there. A lock entry whose source does not match the manifest's is not used, and files whose digest differs from the lock's are refused. |
| Typosquatting and invented names | Look-alike names, and names an assistant made up and someone then registered | Names are GitHub's `owner/repo`; installing one that does not exist fails naming the repository it looked for; the install report shows the release's age, and new releases wait out the minimum release age. |
| Maintainer handoff | A tired maintainer gave a package to a stranger, who added a malicious dependency | Every release records its publisher; `pudu update` and `pudu upgrade` say when a package's publisher changed and when a release adds a dependency. |
| Unpublishing | A deleted package broke every build that used it | Releases are immutable and cannot be deleted, only yanked; a yanked release still installs from an existing lock. |
| Moved tags and branches | A tag was moved to different code | A git dependency is locked to a commit and checked by tree digest. |
| Malicious archives | Path traversal and decompression bombs | Unpacking refuses absolute paths, `..`, links, device files, duplicate paths, and archives over size and file-count limits, and the digest is checked before unpacking. |
| Interception | A download replaced in transit | git and the API speak HTTPS; the lock's commit and tree digest, not the connection, prove the content. |

Beyond these: with a lock present, builds make no network request, and `--offline` guarantees it; a
package may not own `Std` or `Core`; and a program can be run with `pudu run --confined`, which
refuses files, network, and foreign calls to code that should not need them.

## Migration

A project with no manifest keeps compiling as a single file or a directory of modules. A manifest
with path dependencies keeps its meaning. `pudu install` on such a project writes a lock with no
entries and changes nothing else. Moving a local directory to a package is pushing it to GitHub and running `pudu release` in it, then
`pudu install @owner/repo` in the dependent, which replaces the path entry.

## Phases

1. **Local:** manifest with package, path, and git dependencies; `pudu.lock`; `deps/`; tree digests;
   resolution into the program graph; `init`, `install`, `uninstall`, `update`, `deps`, `tree` over
   path and git sources; root and `Std` protection; `--locked` and `--offline`.
2. **GitHub index:** releases as tags, `install @owner/repo` with the requirement solver and the
   cache; `login`, `push`, `release`, `upgrade`; private projects.
3. **Hardening:** archive limits and traversal tests, integrity failures, atomic lock and `deps/`
   updates, deterministic lock snapshots, an end-to-end suite against git and a stand-in GitHub ([[Package end-to-end suite]]), a suite of the
   terminal's install, uninstall, and refusal cases ([[Package install suite]]), repeated
   clean/locked/offline builds producing the same program.
4. **Website:** catalog, handle, project, source, docs, releases, the install dialog, and project
   search, built from the GitHub API at deploy time.

## Open decisions

- **Root ownership across packages.** Roots are unique per program, not across GitHub. Reserving a
  root on first release would prevent most conflicts before they reach a program, at
  the cost of first-come names.
- **Favourites, tickets, contributions.** Resolved: a project renders recent public GitHub issues
  and pull requests as native read-only pages from the deploy snapshot, with direct GitHub links for
  writing, review, and complete history. Stars link to GitHub, with star counts copied at build time.

## Grill Log

- **Q:** Host ticket and contribution writes in Pudu? **A:** No; render the public conversation and link to GitHub for participation. _Rationale:_ identity, permissions, notifications, and review state remain with the repository owner. _Rejected:_ a second Pudu account or write proxy.
- **Q:** Fetch issue and pull request pages on each request? **A:** No; copy the most recently updated public records at build time. _Rationale:_ native pages stay fast and available during a GitHub outage. _Rejected:_ a live GitHub proxy.

- **Q:** Pudu accounts, or GitHub's? **A:** GitHub's, for identity and for source. _Rationale:_ the
  code already lives there and a handle means the same owner in both places. _Rejected:_ Pudu
  passwords and its own device pairing.
- **Q:** Run a registry service beside GitHub? **A:** No; GitHub is the index. _Rationale:_ search by
  topic lists packages, tags are releases, and git reads manifests and files, so there is no service to
  host, secure, or keep alive and no database to lose. A lock pinning commit and tree digest gives the
  reproducibility a stored copy gave. _Rejected:_ a Pudu-hosted API and store; an index repository
  of hand-merged entries.
- **Q:** Keep a copy of each release off GitHub? **A:** No. _Rationale:_ locks pin commits, the machine
  cache keeps what was installed, and a deleted repository is its owner's decision. _Rejected:_ the
  earlier design, which kept a service's copy of every tagged commit.
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
- **Q:** Render package pages per request from GitHub? **A:** No, at build time. _Rationale:_ the
  site is static and answers from a CDN; GitHub's rate limits and outages must not take package pages
  down.
  _Rejected:_ a live proxy in the site's function.
- **Q:** How does a package published after the build appear? **A:** A cached, bounded GitHub overlay
  in the function for the listing, search, and pages the build did not write (#367). _Rationale:_
  publication should not wait on a deployment; edge caching and the snapshot fallback keep the
  outage and rate-limit guarantees above. _Rejected:_ a per-request proxy, and a webhook-triggered
  rebuild as the only path.

## Referenced by

[[architecture/_MOC]] · [[Engineering Delivery]] · [[Compiler Program]] · [[Compiler Library]] · [[Pudu CLI]]
