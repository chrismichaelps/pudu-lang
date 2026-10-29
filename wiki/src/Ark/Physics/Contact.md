---
type: module
path: "@root/lib/Ark/Physics/Contact.pudu"
fidelity: Active
aliases: [Ark Contact]
tags: [module, ark, physics]
---
# Ark Contact

## Purpose and interface

Narrow-phase contact generation on lanes. `Side` holds centers, half extents and the sphere mask;
`Candidate` holds normals and penetration depths for every candidate pair. `Contacts` holds
first/second slot arrays and normal/depth lanes for surviving contacts. `ContactFactory` and
`KindIndicator` describe batch factories and shape masks.

The const `CONTACT_FACTORIES` table maps `sphere|sphere`, `sphere|box`, `box|sphere` and `box|box`
to factories. `KIND_INDICATORS` selects kind pairs. `between(bodies, firsts, seconds)` gathers
candidate sides, evaluates the factories, selects by kind mask and keeps positive depth with
positive total inverse mass. Lane/index mismatches answer None.

`againstPlanes(bodies, planeSlot)` generates movable-body contacts against each plane, using the
supplied body-count slot as the shared static first side. Plane normals point toward the body.
`subset(contacts, members)` gathers contacts in the supplied order or answers None for bad indices;
`joined(first, second)` concatenates all columns in order. Sphere/sphere coincident centers choose
+y. Box overlap chooses the least-overlap axis with deterministic ties. A sphere inside a box
uses the nearest exit face. Finite simulation-scale coordinates are assumed; squared-distance
intermediates may overflow outside that range.

## Grill Log

- **Q:** Branch on kind pairs in the solver? **A:** No; kind pairs map to factories, so a new
  shape adds factories and table rows without touching the solver.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Physics Fixture]]
