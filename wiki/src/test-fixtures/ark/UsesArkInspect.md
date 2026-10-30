---
type: module
path: "@root/test-fixtures/ark/UsesArkInspect.pudu"
fidelity: Active
aliases: [Ark Inspect Fixture]
tags: [module, ark, test, editor]
---
# Ark Inspect Fixture

Derives [[Ark Inspect]] for a scene of bodies (a labelled ranged mass, a vector position, a flag, a
read-only id, a name and a skipped cache) with a gravity vector and a ranged damping. Checks the
rows' paths, labels, kinds, depths, ranges and editability, with the skipped field absent; edits
at every depth (a vector axis inside an array element, a top-level number, a flag, text); and every
refusal with its path: out of range, read-only, unparsable flag and number, an unknown or skipped
field, an index past the array, a path ending at a group and a path past a leaf. Drives
`panel` with recorded input: a click toggles a checkbox and a slider press sets a ranged value,
each answered as the edited value. Prints `ark inspect: ok`.

## Referenced by

[[Ark UI Gate]] · [[Ark Inspect]]
