---
type: script
path: "@root/website/scripts/packages/cache.mjs"
fidelity: Active
tags: [website, packages, build, cache]
aliases: [Package snapshot cache]
---
# Package Snapshot Cache

What one snapshot build leaves for the next. It lives in its own directory (`--cache`, by default
beside `--out` as `<out>.cache`) and holds three things:

- `etags.json`: the GitHub client's stored ETags and bodies.
- `manifests.json`: each tag commit's `pudu.toml` text, keyed by commit SHA. A commit's file never
  changes, so each manifest is read from GitHub once.
- `snapshot/`: a copy of the previous build's output: `packages.json`, the files, API catalogues,
  discussions, and avatars.

`previous(name)` returns a project from the last build. `release key` is the ordered list of version
tags with their commit SHAs. When it and the GitHub release list are unchanged, the generator copies
the project's files and API catalogue from `snapshot/` rather than downloading and documenting the
archive again.

See [[Package snapshot generator]] · [[Package snapshot GitHub client]].

## Grill Log

- **Q:** Keep the cache inside `--out`? **A:** No. _Rationale:_ `--out` is published as it is; the
  cache would ship stored API answers with the site.
- **Q:** Invalidate on `pushed_at`? **A:** No; on the tag list and release list. _Rationale:_ pushes
  to a branch change nothing a package page shows; a new or moved tag does.

Resolved Grill Log: a missing or unreadable cache means a full build, never a failure.
