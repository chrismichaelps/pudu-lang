---
type: module
path: "@root/website/src/Service/LiveRelease.pudu"
fidelity: Active
tags: [website, packages, github, releases]
aliases: [website Service LiveRelease]
---
# Website Service LiveRelease

The releases of one repository the build would admit: each version tag whose `pudu.toml`, read at the
tag's commit, names this package and that version, newest first, bounded per repository. A release is
dated by its GitHub release's publication and carries that release's author and notes; a tag with no
GitHub release is dated by its tagged commit. With `after`, only releases newer than the snapshot's
newest are read. `None` when GitHub cannot list the tags.

Resolved Grill Log: dates come from the release or the commit, never from the repository's last push,
which moves for every unrelated commit. Manifests are read at the commit rather than the tag name, so
the content is addressed immutably and can be remembered for long.

## Referenced by

[[website Service LivePackages]] · [[website/_MOC]]
