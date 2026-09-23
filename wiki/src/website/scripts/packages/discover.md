---
type: script
path: "@root/website/scripts/packages/discover.mjs"
fidelity: Active
tags: [website, packages, build, github, search]
aliases: [Package topic discovery]
---
# Package Topic Discovery

Lists every public, unarchived repository carrying the `pudu-package` topic. GitHub's search returns
at most 1,000 results for any one query, so `discover` asks for `topic:pudu-package
created:FROM..TO`. When a slice reports more than 1,000 results, it splits that date range in half
and asks again. It merges the slices by full name, so a total past 1,000 is listed completely instead
of being cut off. A slice of a single day that still exceeds the cap is listed to its first 1,000 and
reported, since GitHub offers no finer date qualifier.

The search is GitHub's topic index. It does not scan repositories; it names only those whose owners
added the topic.

See [[Package snapshot GitHub client]] · [[Package snapshot generator]].

## Grill Log

- **Q:** Split by stars or by creation date? **A:** Creation date. _Rationale:_ a repository's
  creation date never changes, so slices are stable between builds; stars move while a build runs.

Resolved Grill Log: slices never overlap, merging deduplicates, and `website/scripts/packages/discover.test.mjs`
lists 2,500 synthetic repositories through a search capped at 1,000.
