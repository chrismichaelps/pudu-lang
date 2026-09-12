---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Ui/Layout.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, layout, accessibility, declarative]
aliases: [Std Ui Layout]
---

# Std Ui Layout

## Purpose and interface

A declarative, composable description of an application screen and its placement into a viewport.
A `View` is a value: `box`, `spacer`, `row`, `column`, and `layer` build nodes, and the `Composing`
trait changes one property at a time with `wide`, `tall`, `sized`, `growing`, `padded`, `inset`,
`spaced`, `aligned`, `filled`, `means`, and `named`. Structure nests the way the screen nests;
properties chain along the node they describe.

`place` and `placeWithin` produce a `Layout`: every node's frame, flat, in pre-order. From it,
`frameOf`, `nodeCount`, and `nodeNamed` inspect placement; `semantics`, `focusOrder`, and `hitTest`
give the accessibility tree, keyboard order, and pointer target; `paint` emits the fills into a
[[Std Ui Canvas]]; and `damage` names the regions that differ between two placements so
`Canvas.repaint` redraws only those.

`LayoutError` distinguishes an invalid viewport or budget, a negative or oversized length, node and
nesting budgets exceeded, a leaf forged with children, a meaningful role without a name, a canvas
whose size differs from the viewport, and a drawing refusal carried from the canvas. Node positions in
errors are the same pre-order indices `Layout` uses.

## Governance and algorithm

**A modifier is a field, not a wrapper.** A padded, sized, filled, named box is one node. The order in
which properties are written cannot change their meaning: padding is always inside a fixed size, and a
fill always covers the node's whole frame. Wrapper-per-modifier trees make the same screen depend on
call order and multiply the nodes that layout and diffing must visit.

**Two linear passes.** The first pass measures every node's intrinsic size bottom-up, once, and that
size does not depend on the space offered: a fixed length if one is stated, otherwise the content
(sum along a stack's axis plus gaps, maximum across it, maximum of both for a layer) plus padding. The
second pass gives frames top-down. A stack hands spare main-axis length to growing children by
cumulative weight: each child's share is `spare × weightsSoFar ÷ totalWeight` minus what was already
given, so the shares always sum exactly to the spare length and the remainder falls to the later
children deterministically. Cross-axis `Stretch` fills the content extent unless the child states its
own length; `Start`, `Center`, and `End` position the measured length. Content that does not fit is
not shrunk; it overflows visibly and is clipped by the canvas.

**Bounded arithmetic without widening on the hot path.** Lengths, grow weights, and viewport edges
are refused above 2³⁰ and the node budget is capped at 2²⁴, so every sum of lengths in an admitted tree
stays inside a 64-bit integer. Only the grow share, a product of two potentially large values, widens.

**Accessibility by construction.** Every role other than `Decoration` and `Group` requires a name,
and placement refuses a tree that omits one. The semantics tree is derived from placement, so a frame
an assistive client reports is the frame that was painted. Decoration nodes are transparent to both
the semantics tree (a meaningful node's parent is its nearest meaningful ancestor) and pointing.

**A control's tag is its identity.** Every node carries a tag that defaults to its name; `tagged`
separates identity from the spoken name, so two "Delete" buttons can differ. Placement refuses two
controls with one tag (`DuplicateTag`), which is what lets [[Std Ui Screen]] name an event's source
by tag alone. `nodeTagged`, `tagOf`, and `isControlAt` read identity back from a layout.

**Text is a leaf measured once.** `text` makes a `Words` leaf whose intrinsic content size is its
[[Std Ui Text]] measure at the view's `scaled` face, taken in the measuring pass with every other size.
Non-empty text is a `Label` named by the text itself, so what a screen reader says is what is drawn;
empty text is decoration. Paint draws the text in its `inked` color from the top left of the padded
content. Text is not clipped to its frame: a fixed width narrower than the text leaves the text
visible, and the node's extent—its frame grown to cover the drawn text—is what damage reports, so
repaint stays exact. Scales outside 1 to 64 and text beyond the character bound are refused at
placement.

**Scrolling is a window over a document.** `scrollColumn` and `scrollRow` place their children at
their full lengths in a document shifted by the node's `scrolledTo` offset, clamped between zero and
the content's length beyond the window. Every placed node records the window of its scrolling
ancestors as its clip; painting cuts fills and glyph rectangles to it, hit testing ignores points outside
it, and damage reports extents cut to it, so content scrolled out of view is neither drawn nor pressed
and a scroll repaints to the same bytes as a full render. `scrollOffsetOf` and `scrollRangeOf` read the
clamped offset and how far a node can scroll. A negative offset is refused like any negative length.

**Damage is data.** A node that changed its extent, frame, fill, text, ink, scale, or origin damages
where it was and where it is if it paints; a region identical to the one just recorded is recorded
once, so a recolored node damages its extent a single time. A change of structure or viewport damages the whole viewport. More than sixteen
regions merge into their bounding rectangle. Repainting the damage of an earlier surface equals a full render of the
later layout, which the fixture checks byte for byte.

## Measured

At -O2 on the development host, with a 1,001-node screen of 100 growing rows of nine named buttons
at 1024×768, medians of three runs: building the view tree 0.14 s including process startup, placing
it about 0.18 s beyond that, and painting plus rendering about 0.56 s beyond placement, at 117 MB
resident. These are interpreter costs and far outside an interactive frame budget; the release gate in
[[Native Application UI]] still requires percentile frame times before any interactive claim.

## Referenced archive material

Apple's archived view-drawing guidance coalesces invalidated regions and discourages hundreds of
heavyweight view objects in favor of lightweight elements managed by one owner; here every node is a
record in one flat array. The archived accessibility guide's element hierarchy with role-specific
required properties becomes a refusal at placement time. The parent-proposes, child-chooses size
negotiation seen in OpenSwiftUI is simplified to proposal-independent intrinsic measurement so each
node is measured exactly once.

## Grill Log

- **Q:** Wrap each modifier in its own node? **A:** No. _Rationale:_ it makes meaning depend on call
  order and multiplies nodes. _Rejected:_ modifier wrapper trees.
- **Q:** Let intrinsic size depend on the proposal? **A:** Not in this slice. _Rationale:_ text
  wrapping will need it, but boxes and stacks do not, and a proposal-independent measure is computed
  once per node. _Rejected:_ re-measuring children for every proposal. Revisit with text layout.
- **Q:** Shrink children that overflow? **A:** No. _Rationale:_ silent shrinking hides a layout defect;
  overflow is visible and clipped. _Rejected:_ implicit compression.
- **Q:** Allow a button without a name? **A:** No. _Rationale:_ an unlabeled control is unusable with a
  screen reader and is cheapest to catch where the tree is built. _Rejected:_ warnings or empty labels.
- **Q:** Round grow shares per child? **A:** No. _Rationale:_ independent rounding can lose or invent a
  pixel. _Rejected:_ per-child rounding; cumulative division is exact.
- **Q:** Name the lookup `named` like the modifier? **A:** No. _Rationale:_ a module function and a
  trait method of one name invite ambiguity at call sites. _Rejected:_ `named` for both.

Resolved Grill Log: placement is two passes with exact integer distribution, every refusal is typed,
accessibility is derived from placement, and damage feeds canvas repaint with equality checked.

## Referenced by

Depends on [[Std Ui Canvas]], [[Std List]], [[Std Math]], `Std.Num.Integer`, and [[Std Option]].

Consumed by [[Uses Ui Layout]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
