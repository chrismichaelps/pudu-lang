---
type: module
path: "@root/website/src/View/Documentation.pudu"
fidelity: Active
tags: [website, view, documentation]
aliases: [website View Documentation]
---
# Website View Documentation

Renders versioned module indexes, symbol-family detail pages, the concise language guide, and
not-found responses. A symbol page lists every same-kind, same-name declaration and signature so
trait methods, implementations, and overloads remain visible at one stable canonical path. Kind is
part of the path so `stage` the function and `Stage` the type cannot collide on a case-insensitive
filesystem.

Each declaration starts with its source-derived signature. A concise kind explanation and a
conditional signature guide explain arrows, references, mutable references, type arguments,
`Option`, and `Result` only when those forms occur. This teaches the notation without inventing
parameter meaning that the current documentation schema does not carry.

Both explanations read from module-scope constant tables: `KIND_EXPLANATIONS` maps a plainly
written kind to its sentence, and `SIGNATURE_NOTES` pairs each signature marker with the note it
earns, walked in the order a reader meets them. A method's kind names the type or trait it belongs
to, so those two stay prefix tests rather than table entries.

Documentation prose is rendered by [[website View Prose]], which turns the exporter's untouched
lines into paragraphs, examples, section headings, and cross-reference lists. The view adds no
notation guide of its own: a sentence repeated on every declaration is page furniture, not
documentation. The only sentence it still supplies names where a trait method comes from, which the
kind alone does not say.

Resolved Grill Log: signatures are prominent, prose stays readable, and source-derived facts are not
rewritten in the view layer. Missing-page HTML delegates to the bounded dynamic view so edge fallback
and local routing use one no-index response.
Derived signature help is limited to stable language notation; parameter-specific prose remains
source-owned documentation and is not guessed by the view.
