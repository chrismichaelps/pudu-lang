---
type: module
path: "@root/website/src/View/Packages/Suggest.pudu"
fidelity: Active
tags: [website, packages, search, view]
aliases: [website View Packages Suggest]
---
# Website Package Suggestions

Encodes [[website Service PackageSearch]] suggestions as the JSON body of
`GET /packages/suggest?q=&filter=`. The box under every package search field reads it.

```json
{
  "query": "json", "filter": "",
  "handles": [{"handle": "@alice", "name": "Alice", "avatar": "…", "tone": 1, "href": "/@alice", "projects": 1}],
  "projects": [{"name": "@alice/json-kit", "handle": "@alice", "project": "json-kit", "description": "…",
                "latest": "2.0.0", "stars": 1284, "avatar": "…", "tone": 1, "href": "/@alice/json-kit"}],
  "declarations": [{"name": "textOf", "module": "JsonKit.Value", "kind": "fn", "mark": "ƒ", "signature": "…",
                    "project": "@alice/json-kit", "version": "2.0.0", "href": "/@alice/json-kit/docs#…"}],
  "totals": {"projects": 1, "declarations": 3},
  "more": "/packages/search?q=json"
}
```

Every link is a site path built here, never by the browser, so the script concatenates nothing into
an address. `avatar` uses the same source preference as the rendered pages ([[website View Packages Frame]]);
`tone` selects the two-tone mark shown when the image is absent. `more` is the full results page for
the same query and filter. Text is carried verbatim; the script inserts it as text, never markup.

See [[website Web Routes]] · [[website Web Dynamic]] · [[src/website/_MOC]].

## Grill Log

- **Q:** Keep parsing the rendered results page in the browser? **A:** No. _Rationale:_ it fetched
  and parsed a full document per keystroke and coupled the box to page markup; a small JSON body
  is cheaper and states its contract.
- **Q:** Let the script build links? **A:** No. _Rationale:_ anchors depend on the docs view's
  anchor rule; one place builds them.

Resolved Grill Log: the body is bounded by the service limits, names only public snapshot data, and
is served by both the local router and the dynamic function.
