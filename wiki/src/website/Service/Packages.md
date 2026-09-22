---
type: module
path: "@root/website/src/Service/Packages.pudu"
fidelity: Active
tags: [website, packages, service]
aliases: [website Service Packages]
---
# Website Service Packages

Loads one build-time snapshot of public registry documents, GitHub profiles, latest-release files, and API catalogues. Missing snapshot means an empty catalogue; malformed names or missing release file trees fail startup. Search ranks exact project names, handles, names containing the query, then description and keyword matches. File reads are confined to the snapshot's listed release files. Text and raw byte reads distinguish a valid binary release file from a missing snapshot file.

See [[architecture/PACKAGES]] · [[website Site]] · [[src/website/_MOC]].

## Grill Log

- **Q:** Fetch registry data per request? **A:** No; load a generated snapshot once. _Rationale:_ package pages remain available during a registry outage.

Resolved Grill Log: only public registry documents enter the snapshot; the service admits files by its generated listing and serves no unlisted path.
