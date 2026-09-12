---
type: module
path: "@root/test-fixtures/stdlib/UsesUiLayout.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, ui, layout]
aliases: [Uses Ui Layout]
---

# Uses Ui Layout

## Purpose and interface

Executable Pudu fixture for declarative layout. Its `main` returns 40 held assertions.

Text views: a padded label's measured frame, its semantics entry named by its text, and its glyph
pixels at the padded origin; a scaled, inked label's frame and pixels; a refused scale; a text leaf
forged with children; empty text as unnamed decoration; and changed text overflowing a fixed width
damaging its full extent with repaint equal to a full render.

Identity: tags that separate two controls sharing a spoken name, lookup by tag that ignores
non-controls, tag and control queries outside the layout, refusal of two controls with one tag, and a
recolored node damaging its frame exactly once.

Refusals: zero viewport, zero node budget, negative and oversized lengths, a forged leaf with
children, an unnamed button, node and nesting budgets, and painting onto a canvas of another size.

Placement: the root filling the viewport, padding with gaps, weighted growth, exact remainder
distribution across thirds, center and end alignment on both axes, layers that stretch or align,
overflow without shrinking, padding larger than its frame, and grow shares at the 2³⁰ length limit.

Meaning and interaction: the semantics tree with decoration skipped for parents, focus order,
lookup by name, and hit testing that ignores decoration.

Pixels and damage: painting in order with children in front, no damage for identical layouts, exact
damage for a moved fill, byte equality between repaint of that damage and a full render, whole-viewport
damage for a structural change, and merging of more than sixteen regions.

## Grill Log

- **Q:** Check only that placement succeeds? **A:** No. _Rationale:_ layout defects are wrong frames,
  not failures. _Rejected:_ success-only tests; every case compares exact rectangles.
- **Q:** Trust damage without rendering? **A:** No. _Rationale:_ the contract is pixel equality.
  _Rejected:_ comparing region lists alone.

## Referenced by

[[Std Ui Layout]] · [[Service Evaluation Spec]]
