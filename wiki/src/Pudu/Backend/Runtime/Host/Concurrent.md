---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Concurrent.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Concurrent]
---
# Native Host Concurrent

Export the family's runtime parts and their prerequisites.

Cells, locks, channels and threads behind their tokens. A held value is a box of one member; the function that releases the box names its type.

Its forward declaration of `pudu_frame_depth` carries no attribute, because the definition now precedes every body ([[Backend Frame Runtime]]); a plain tentative declaration is valid on either side of it.

A failure on a started thread runs the cleanup hook before the long jump, so stack frames of direct functions release their owned values while their storage is still live.

The first cell opened arranges `pudu_host_cells_end` at exit. It releases every cell still registered exactly as `disposeCell` does (drop the held box, free the cell, forget its token), so a cell the program never disposes lives as long as the program and is then released (#1026). The exiting thread holds the run gate, so no other thread reaches a cell during the release.

## Resolved Grill Log

A started thread's failure ends that thread, not the program. Threads take turns through the run gate.

The gate counts live worker threads from registration until successful or
failed completion. Both exits retire the count before leaving the gate, so
the main thread skips scheduler clock checks after the last worker exits
when no external callback gate has been enabled.

- **Q:** May an undisposed cell stay allocated past the end of the program? **A:** No; the counted-allocation run found every `Std.Html.Memo` program ending with live blocks. Cells are released at exit like constant cells and the kept-HTML cache. Rejected: requiring every program to dispose its cells, which the interpreter does not require.

## Mutex close (#935)

Close retires an available mutex immediately. Closing an owned mutex stops
admission while the closer waits through the run gate. The owner's release
retires the token and wakes the closer. Self-close is refused and leaves the
owner able to release the mutex normally.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
