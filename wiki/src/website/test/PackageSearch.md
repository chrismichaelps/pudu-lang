---
type: module
path: "@root/website/src/Test/PackageSearch.pudu"
fidelity: Active
tags: [website, tests, packages, search]
aliases: [website package search suite]
---
# Website Package Search Suite

Checks [[website Service PackageSearch]] and [[website View Packages Suggest]] against a snapshot
built from the `@alice/json-kit` fixture plus synthetic projects and declarations.

- **Success:** identifier splitting; shape detection for arrows, brackets, and capitalised word
  pairs; name ranking order (exact, qualified suffix, prefix, containment, module); shape matching
  across module qualification; result-position preference; `@owner`, `@owner/prefix`, and display-name
  handle and project matches; title-case project and owner queries; a repeated shape identifier
  counted once; filter browsing in snapshot order.
- **Failure:** an unknown filter and a missing type yield nothing; a shape query suggests no project
  or handle; an empty query without a filter suggests nothing.
- **Bounds:** suggestions stop at the service limits while totals count every match; the reply cuts
  an overlong query.
- **Standard library:** a shape ranks library entries by result type; the reply links them to their
  symbol pages with the API search as `libraryMore`; a filtered reply has no library group.
- **Output:** the reply is `200` JSON with site-built project, handle, and declaration links, kind
  marks, and the full-results path carrying the filter.

Route wiring for the local router and the dynamic function is checked in [[website regression suite]].

See [[src/website/_MOC]].

## Grill Log

- **Q:** Add these checks to the website suite? **A:** No. _Rationale:_ that suite is past the
  size a reader can hold; ranking deserves its own file, and the route checks stay beside the
  other route checks.

Resolved Grill Log: the suite covers success, failure, bounds, and output for the search service and
its JSON reply.
