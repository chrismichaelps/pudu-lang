---
type: module
path: "@root/src/Pudu/Doc/Site.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.5
tags: [module, medium]
aliases: [Doc Site]
---

# Doc Site

## Purpose

Render a complete documentation index as one static, searchable HTML page that can be opened from
disk or hosted by any ordinary file server.

## Interface

### Signatures

```haskell
renderSite :: DocIndex -> Text
```

### Governance

- The output is one self-contained UTF-8 HTML document. It has no runtime package, network,
  server, or asset-path dependency, so the same artifact works from `file:`, a project pages host,
  or a release archive.
- The page embeds the [[Doc Json]] index and presents its existing fields; it does not rebuild
  documentation from source text or written type annotations.
- Browser search follows [[Doc Query]] and [[Doc Search]]: a query containing `->` is a type shape;
  otherwise it is a name. Name results rank exact, prefix, infix, then subsequence matches. Shape
  results preserve the same exact, reordered-arguments, contained-arguments, and result-only
  ladder, including the asymmetric meaning of signature and query variables.
- Search is progressive, submit-capable, and reflected in the `q` URL parameter. A linked query
  therefore opens to the same result set without requiring a server route.
- The initial page shows the index in declaration order. Blank input restores that state; a
  completed query with no matches renders an explicit empty state rather than an empty page.
- Source-authored names, modules, signatures, and comments are inserted through DOM text nodes.
  Embedded JSON escapes markup-opening scalars before entering the script element, so a comment
  containing `</script>` cannot escape the data boundary.
- The result list and search control remain usable with a keyboard, narrow viewport, reduced
  motion, and the browser's default zoom. Visual treatment uses text and CSS only; it does not
  require generated imagery.

### Linkage

- **Requires:** [[Doc Json]], [[Doc Query]], [[Doc Search]].
- **Consumed by:** [[Pudu CLI]].

## Algorithm

Encode the index once, neutralize markup-opening scalars in that encoding, and place it beside a
fixed HTML/CSS/JavaScript shell. The shell parses the structured signature shape already carried
by the JSON, ranks entries in the browser, and renders result cards with DOM construction rather
than HTML interpolation.

## Negative Logic (Prohibited Paths)

- No web server, framework, package-manager runtime, CDN, font request, analytics, or external
  asset. Documentation generation remains deterministic and offline.
- No `innerHTML` or source-authored value in executable JavaScript or CSS.
- No second documentation schema and no parsing of the rendered signature when its structured
  shape is already present.
- No mutation of the index and no compiler invocation from browser code.

## Edge Cases

- An empty index still produces a complete page with an explicit zero-entry state.
- An entry without a signature remains findable by name and renders without a fabricated type.
- Malformed or incomplete type-shape input yields no matches while the reader is typing; it does
  not fall back to an unrelated name search.
- Query length and nesting use [[Doc Query]]'s 512-scalar and 64-level budgets, so pasted hostile
  shapes reach the same no-match state instead of exhausting the browser stack.
- Duplicate declarations render as separate results with their module and kind provenance.

## Depth

DEPTH 0.50 (MEDIUM). The module owns a browser projection and its safety boundary, while indexing,
query meaning, and ranking remain owned by the existing documentation modules.

## Grill Log

- **Q:** Should the documentation site be a long-running compiler web server? **A:** No.
  _Rationale:_ the index is immutable output, and a server would add process lifecycle, port,
  network, and deployment contracts without improving the reader's answer. _Rejected:_ `pudu doc
  --serve`; a framework application requiring a JavaScript build.
- **Q:** Should the page fetch a sibling JSON file? **A:** No. _Rationale:_ browsers restrict
  `file:` fetches, two artifacts can drift, and a self-contained page is equally hostable.
  _Rejected:_ `index.html` plus `index.json`.
- **Q:** Should browser search support only names and leave type search to the CLI? **A:** No.
  _Rationale:_ type-shape search is the feature that makes this Hoogle-like, and removing it would
  make the web surface weaker than the index it presents. _Rejected:_ substring-only filtering.
- **Q:** May encoded JSON be copied raw into a script element because it is already valid JSON?
  **A:** No. _Rationale:_ JSON escaping and HTML parsing are different boundaries; `</script>` in
  a doc comment would terminate the element. _Rejected:_ raw `encodeIndex` insertion; HTML string
  interpolation of entry fields.

## Referenced by

[[src/Pudu/Doc/_MOC]] · [[Pudu CLI]] · [[Tooling]]
