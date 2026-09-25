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

Both are addressed by a commit, so what they answer never changes: they are remembered with the
`immutable` freshness (a week fresh, a month stale) for as long as the cache holds them. The raw host
does not spend the API's rate limit. [[website Service LivePackages]] reads only the file the page
shows, the asked one or else the first, and hands its bytes to the Source view through the project's
`bodies`, which `Packages.fileText` and `fileBytes` consult before the snapshot's directory.

Resolved Grill Log: files are addressed by commit rather than tag, because a tag can be moved and a
commit cannot. _Rejected:_ downloading the release archive, which reads every file to show one.

`catalogue` reads the API reference `pudu release` attaches to a release as `pudu-api.json`, parsed by
`Catalog.parse`. It uses the `changing` freshness, not the immutable one, so a catalogue attached by a
release run again appears within minutes; a release without one keeps the Docs tab's own note.

## Referenced by

[[website Service LivePackages]] · [[website live pages suite]] · [[website/_MOC]]
