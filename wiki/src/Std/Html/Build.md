---
type: module
path: "@root/lib/Std/Html/Build.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, html, builder]
aliases: [Std Html Build]
---

# Std Html Build

## Purpose

Provide a fluent, persistent HTML node builder while preserving [[Std Html]] as the only renderer
and safety boundary. A builder node is a value: every method returns a new node, so a partial node
can be reused without shared mutation.

## Interface

`Node` stores one tag name, ordered attributes, and ordered `Html` children. `Building` supplies the
general attribute, flag, text, trusted-markup, child, conditional-child, and conversion operations,
plus named methods for common attributes. Tag constructors cover document structure, text content,
forms, tables, media, and common semantic elements. `render` emits a fragment; `document` emits the
builder-specific compact `<!DOCTYPE html>` prefix followed by the root node.

`at`, `href`, `src`, `action`, and the other string setters are convenience setters, not checked
destination constructors. The renderer still drops event-handler attributes as a final backstop.
Callers needing the stronger checked-destination contract use [[Std Html]] constructors directly.

## Algorithm and boundaries

Node methods append to persistent arrays and never render eagerly. `html` converts an ordinary node
to `Html.Element`; the empty-name nodes produced by `words` and `nothing` convert to fragments.
`holding` preserves source order while converting child nodes. Rendering delegates to `Std.Html`, so
escaping, void-element spelling, handler blocking, iterative traversal, and trusted-markup behavior
have one implementation.

`document` prepends its prefix to `Std.Html.renderChunks` before the final join rather than render the
body to one string and then concatenate the prefix. Its prefix deliberately has no newline, unlike
`Std.Html.document`. That whitespace is observable and remains stable.

## Dependencies and consumers

The module depends only on [[Std Html]]. Its fluent API is exercised by
`test-fixtures/stdlib/UsesHtmlBuild.pudu`; server-side rendering consumers may convert a node through
`html` and then use the lower-level prepared or streaming APIs.

## Grill Log

- **Q:** Duplicate the renderer for fluent nodes? **A:** No; convert to `Html` and retain one safety
  and output contract. _Rationale:_ two renderers would drift on escaping, void elements, and handler
  refusal. _Rejected:_ a builder-specific serializer.
- **Q:** Make every fluent destination setter return `Result`? **A:** Not in this performance issue.
  _Rationale:_ that is a public compatibility and safety redesign tracked separately; changing it
  here would mix API semantics with traversal mechanics. _Rejected:_ silently changing setter
  signatures while optimizing rendering.
- **Q:** Normalize both document prefixes? **A:** No; preserve their existing bytes. _Rationale:_
  output is observable and current callers may compare exact documents. _Rejected:_ adding or
  removing the newline for consistency.
- **Q:** Prefix after rendering? **A:** No; prepend it to the fragment collection before the one
  final join. _Rationale:_ the body should not be materialized and then copied solely to add a
  constant prefix. _Rejected:_ string concatenation after `Html.render`.

## Referenced by

[[src/Std/_MOC]] · [[Std Html]] · [[architecture/STDLIB]]
