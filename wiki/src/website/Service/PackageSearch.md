---
type: module
path: "@root/website/src/Service/PackageSearch.pudu"
fidelity: Active
tags: [website, packages, search, service]
aliases: [website Service PackageSearch]
---
# Website Service PackageSearch

Ranks package search results from the loaded snapshot. One implementation serves the suggestion
endpoint and the full `/packages/search` page, so the box under the search field and the page it
leads to never disagree about order.

A query takes one of four forms:

| Form | Example | Matches |
| --- | --- | --- |
| owner | `@alice` | handles starting with it, then that owner's projects |
| project | `@alice/js` | that owner's projects whose name starts with the rest |
| name | `textOf`, `Value.textOf` | declarations by name, qualified suffix, prefix, containment, then module |
| shape | `Str -> Int`, `Array Value` | declarations whose signature holds every named type |

A query is a shape when it holds `->`, a bracket, or two or more words that each start with a
capital letter. A single capitalised word stays a name query, so `Value` finds the `Value` type by
name. Only an arrow or a bracket (`isSignature`) rules out projects and owners: title-case words such
as `JSON Helpers` or `Bruno Díaz` still match projects by description and owners by display name. Shape matching compares identifiers case-insensitively; each identifier missing from the
signature disqualifies it, and signatures with fewer extra identifiers rank first. Repeated
identifiers count once, so `Int -> Int` prefers `Int -> Int` over `Str -> Int`. When the shape
names a result after its last `->`, a signature whose own result holds those identifiers ranks ahead.

Name scores: exact name 0, qualified or qualified suffix 1, name prefix 2, name containment 3,
qualified containment 4. Ties break on shorter name, then qualified name. Projects keep the
[[website Service Packages]] ranking.

A filter is a project name. It restricts declarations to that project and suppresses handle and
project suggestions; with an empty query it lists that project's declarations in snapshot order.
An unknown filter yields no declarations rather than falling back to every project.

`suggest` returns bounded lists (3 handles, 5 projects, 8 declarations) and the unbounded totals,
so the box can say how many results the full page holds.

See [[website View Packages Suggest]] · [[website View Packages Catalog]] · [[architecture/PACKAGES]] · [[src/website/_MOC]].

## Grill Log

- **Q:** Rank in the browser from a downloaded index? **A:** No. _Rationale:_ the declaration set
  grows with every published package; the dynamic function already holds the compact snapshot and
  answers a bounded list.
- **Q:** Treat any capitalised word as a type query? **A:** No; only two or more, or an arrow or
  bracket. _Rationale:_ a reader typing `Value` usually wants the declaration named `Value`, and a
  name query still finds it.
- **Q:** Match shapes by exact signature text? **A:** No; by identifiers. _Rationale:_ readers do
  not know module qualification or spacing, and `Value -> Str` must find
  `JsonKit.Value.Value -> Str`.
- **Q:** Should an unknown filter widen to every project? **A:** No. _Rationale:_ a narrowed box
  that silently widens shows results the reader excluded.

Resolved Grill Log: ranking is deterministic, bounded for suggestions, shared with the full page,
and reads only the snapshot.
