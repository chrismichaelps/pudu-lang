---
type: module
path: "@root/website/src/Service/LiveFiles.pudu"
fidelity: Active
tags: [website, packages, github, source]
aliases: [website Service LiveFiles]
---
# Website Service LiveFiles

The Source tab of a release the build has not seen. `listed` reads the git tree at the release's
commit (recursively), keeping blobs of at most 1 MiB that the package ships, sorted, at most 2,000;
`body` reads one file's bytes from the raw host at the same commit, each path segment encoded.
`shipped` is the build's rule: nothing named with a leading dot or under a dot directory, and nothing
under a top-level `deps/`.
`defaultFile` chooses README, manifest, then the first sorted file for both the live body fetch and
the Source view. The two must agree or the default Source route has a file list but no preview body.

Both are addressed by a commit, so what they answer never changes: they are remembered with the
`immutable` freshness (a week fresh, a month stale) for as long as the cache holds them. The raw host
does not spend the API's rate limit. [[website Service LivePackages]] reads only the file the page
shows, the asked one or else the first, and hands its bytes to the Source view through the project's
`bodies`, which `Packages.fileText` and `fileBytes` consult before the snapshot's directory.

Resolved Grill Log: files are addressed by commit rather than tag, because a tag can be moved and a
commit cannot. _Rejected:_ downloading the release archive, which reads every file to show one.

`catalogue` reads the API reference `pudu release` attaches to a release as `pudu-api.json`, parsed by
`Catalog.parse`. It uses the `changing` freshness, not the immutable one, so a catalogue attached by a
release run again appears within minutes.

`derived` builds the reference of a release that carries no catalogue — released by a tool that
does not attach one, or not yet attached — from the release's own sources at its commit. It lists
the tree, keeps the `.pudu` files `ofRoot` accepts (the package root's file and everything beneath
its directory, never `test/` or `tests/`), reads at most 400 of them sixteen at a time from the raw
host, and reads each with [[website Domain Declarations]]; only modules that are the root or under
it are kept. Every read is addressed by the commit and remembered as immutable, so a release is
read once. A file that cannot be read is left out; no declaration at all answers `None`, and the
Docs tab keeps its own note.

Resolved Grill Log: the Docs tab must never depend on how a release was published. _Rejected:_
requiring every package to attach `pudu-api.json`, which leaves any release made with an older
tool, or whose upload failed, without a reference until the next site build.

## Referenced by

[[website declarations suite]] · [[website Service LivePackages]] · [[website live pages suite]] · [[website/_MOC]]
