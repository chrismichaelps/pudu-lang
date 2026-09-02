---
type: module
path: "@root/lib/Std/Ui.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, ui, components, diff]
aliases: [Std Ui]
---
# Std Ui
## Purpose
A screen as a function from what is known to what is shown, and the difference between two of them.
## Interface
A component: a state, the view it renders to, and how an event changes it. Building one, reading its
state, giving it an event, and rendering it. Composing components so a screen is made of screens.
A change: the path to the node that differs and what it became. The changes between two views, and
applying them, so the two ends can agree on a screen without either sending the whole of it.
Whether an event is answered where it happened or where the state is.
## Governance and algorithm
A component is a pure function from state to view. That is what makes the rest possible: rendering
twice with the same state gives the same view, so the difference between two renders is exactly the
difference the state made, and a screen can be checked by comparing values rather than by driving
one.

The difference between two views is computed by walking both together. A node whose element name
changed is replaced whole rather than reconciled, because an element that became a different element
shares nothing with what it was and pretending otherwise produces a wrong tree that renders
plausibly. Text and attributes are compared in place. A path names a node by the indices that reach
it from the root, which is a value both ends can hold without either keeping a copy of the tree.

**Where an event is answered is a property of the event.** The established server-rendered model
sends every interaction to the server and waits, so a control that could have answered immediately
waits for the network, and a viewer holds server state for as long as they are looking. Here an
event says which it is: one that only needs what is already on the screen is answered where it
happened, and one that needs what only the server knows makes the trip. That distinction is in the
event's type, so a component states it once rather than a framework guessing per interaction.
## Grill Log
- **Q:** Reconcile two elements of different names by matching their children? **A:** No.
  _Rationale:_ an element that became a different element shares nothing with what it was; matching
  children produces a tree that is wrong and renders plausibly, which is the worst failure available
  here. _Rejected:_ name-agnostic reconciliation.
- **Q:** Identify nodes by a caller-supplied key? **A:** Not in this first surface. _Rationale:_ keys
  matter when a list is reordered, and a wrong key is worse than no key because it moves the wrong
  state. Positional paths are correct always and inefficient only for reordering. _Rejected:_ keys
  without a stated rule for what happens when one is duplicated.
- **Q:** Answer every event at the server, as the reference model does? **A:** No. _Rationale:_ that
  makes latency a property of the framework rather than of the interaction, and holds server memory
  per viewer for the whole of a session. _Rejected:_ a uniform round trip.
- **Q:** Let a component read the clock or a connection? **A:** No. _Rationale:_ a component that is
  not a function of its state cannot be compared, and comparison is how every check here works.
  _Rejected:_ effects inside render.
## Referenced by
[[src/Std/_MOC]] · [[Std Html]] · [[ADR-0016 An Application Is a Value]] · [[architecture/STDLIB]]
