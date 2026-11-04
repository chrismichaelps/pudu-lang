---
type: handoff
status: IN_REVIEW
issue: 673
aliases: [Game Input Delivery]
tags: [handoff, delivery, desktop]
---
# Game Input Delivery

Fresh feature/673-game-input from development b230a5d6. Role transitions: Platform Engineer →
independent Forensic Guardian. Observed: the macOS adapter reported no key release, no physical
key codes, no hover and no secondary buttons, so held-key game input was impossible. Added the
game input records documented in [[pudu-desktop-adapter]] while preserving every existing record.

Evidence: the adapter compiles with `-Wall -Wextra` clean and the compiler builds; interface
decoding skips the new records by its existing rule. Synthesized OS events need accessibility
permission and were not injected here; the engine platform layer's decoder carries the checked
fixture. No full gates were run locally, by request.

Exact next action: decode these records in Ark.Platform input state and action maps.

## Referenced by

[[handoffs/_MOC]] · [[pudu-desktop-adapter]]
