---
type: module
path: "@root/website/src/View/Pudu.pudu"
fidelity: Active
tags: [website, view, motion]
aliases: [website View Pudu]
---
# Website View Pudu

`around(mode, banner)` wraps a page's banner so the [[Pudu mascot script]] can put a pudu behind it:
an isolated host holding an empty, `aria-hidden` stage that names the mode, the banner, and the
module script. The stage precedes the banner and sits one layer below it, so the banner covers the
pudu's lower half. `ROAM`, `SHY`, and `ASK` name the modes; [[website View Home]] uses the first,
[[website View Dynamic]] the missing page's `SHY`, and [[website View Donation]] `ASK`, which also
names the support link as the stage's target.

`raised` hosts add the room a page banner lacks above it; the home banner already has it.

## Grill Log

- **Q:** A mode type with a match? **A:** String constants. _Rationale:_ the value only travels to
  the script as an attribute, and the constants are the whole vocabulary the script accepts.
