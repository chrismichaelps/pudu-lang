---
type: module
path: "@root/website/src/Service/Packages.pudu"
fidelity: Active
tags: [website, packages, service]
aliases: [website Service Packages]
---
# Website Service Packages

Loads one build-time snapshot of public GitHub repositories, profiles, latest-release files, API catalogues, and recent public issues and pull requests. Missing snapshot means an empty catalogue; malformed names or missing release file trees fail startup. Search ranks exact project names and `@owner/prefix` matches, then handles and `@prefix` matches, names containing the query, then description and keyword matches. An `@` query matches only owners and their projects. [[website Service PackageSearch]] adds handle and declaration ranking on top of this project order. File reads are confined to the snapshot's listed release files. Text and raw byte reads distinguish a valid binary release file from a missing snapshot file.
Compact declaration names, modules, kinds, and signatures stay in each project document so dynamic
package search works in the serverless function without the larger static API catalogue files.
The full loader requires the latest release tree and reads per-project discussion documents.
The compact loader validates the project index without requiring static release, API, or discussion files.
The list page size is shared with the catalogue, conversation views, and canonical path generator.
Owner profiles retain both the locally copied GitHub avatar and the original GitHub avatar URL.
The view can use the original URL if the snapshot copy fails, while rejecting unrelated image hosts.

See [[architecture/PACKAGES]] · [[website Site]] · [[src/website/_MOC]].

## Grill Log

- **Q:** Where do stars, tickets, and contributions come from? **A:** The build snapshot copies the repository's star count and the latest public issues and pull requests from GitHub. _Rationale:_ no page asks GitHub at request time.

- **Q:** Fetch GitHub data per request? **A:** No; load a generated snapshot once. _Rationale:_ package pages remain available during a GitHub outage. Since #367 the function lays a cached GitHub overlay on this snapshot ([[website Service LivePackages]]); the snapshot stays the baseline and the fallback.

- **Q:** Require release trees in the search function? **A:** No; use a compact loader there and the full loader for static pages. _Rationale:_ the function bundle carries only the project index.

Resolved Grill Log: only public GitHub documents enter the snapshot; the service admits files by its generated listing and serves no unlisted path.
Discussion records are read-only and bounded; a requested number must match a record in that project's snapshot.
