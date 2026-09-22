---
type: script
path: "@root/website/scripts/generate-packages.mjs"
fidelity: Active
tags: [website, packages, build]
aliases: [Package snapshot generator]
---
# Package Snapshot Generator

Pages through the public registry catalogue and copies project documents, handle profiles and avatars, latest-release files, and a normalized API catalogue into `website/data/packages/`. The generated snapshot is the only package input to the website build. Names and file paths are checked before use; file requests run with bounded concurrency and deadlines. An invalid package's API source omits only that package's reference, leaving its other pages available. An empty public catalog removes a prior snapshot.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

Resolved Grill Log: the public list selects projects, and a missing or invalid selected project fails the build; no private token is passed to the generator.
