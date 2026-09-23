---
type: module
path: "@root/website/src/View/Packages/Reference.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Reference]
---
# Website Package Reference

Renders the latest release's generated public API catalogue by module and declaration. It uses the standard library catalogue reader and inline documentation renderer.

The tab opens with the shared tab heading, then a two-column layout: a sticky module index with a
left rule (module names in monospace) beside the modules. Each module is a monospace heading over a
ledger of declarations; a row shows the kind mark shared with search ([[website View Packages Frame]]
`kindMark`), the name and signature as one linked line, the kind word, and the documentation beneath.
A targeted declaration is tinted with a blue left edge. Below 900px the index becomes a wrapping row
of links above the modules.

See [[architecture/PACKAGES]] · [[website Service Catalog]] · [[website Service Packages]].

## Grill Log

- **Q:** One card per declaration? **A:** No; rows in a ledger. _Rationale:_ readers scan names and
  signatures down a column, and cards spent space and borders on every entry.

Resolved Grill Log: absent generated documentation gets an explicit empty state; no declaration is invented from raw source text.
