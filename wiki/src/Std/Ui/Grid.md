---
type: module
path: "@root/lib/Std/Ui/Grid.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, layout, grid]
aliases: [Std Ui Grid]
---

# Std Ui Grid

## Purpose and interface

Cells in rows of equal flexible columns, built from [[Std Ui Layout]] rows and columns.

Exports: `grid(columns, cells, spacing)`, `rowsFor(count, columns)`, `cellAt(index, columns)`,
`columnsFitting(width, minimum, spacing)`.

## Semantics

- Each column takes an equal share of the width; a short last row is padded with empty cells so its
  columns line up with the rows above.
- `columnsFitting` answers how many columns of a minimum width fit, for a grid that reflows as its
  window resizes.

## Grill Log

- **Q:** A new placement kind in `Layout`? **A:** Not for equal columns: composition over rows of
  growing cells gives the same frames, and `Layout` stays one placement algorithm. Columns sized to
  their widest cell need measurement inside placement and are recorded as absent.

## Dependencies and consumers

- Depends on [[Std Ui Layout]].
- Consumed by galleries, dashboards, and settings panes.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
