---
type: module
path: "@root/test-fixtures/ark/UsesArkGame.pudu"
fidelity: Active
aliases: [Ark Game Fixture]
tags: [module, ark, game, test]
---

# Ark Game Fixture

## Purpose and interface

Drives a counter scene with chosen clock readings: two owed fixed steps and one update, the kept
interpolation fraction, an action press reaching the update, a stalled clock owing nothing, the
step budget capping catch-up, and drawing the top scene. Pushes, steps only the top, pops,
replaces and quits; an empty stack or a hook answering None finishes the app, which then stays
fixed. The follow rig moves monotonically without overshoot, stays stable for a 1,000-second step
and refuses bad parameters; the orbit places its eye, zooms, clamps pitch and refuses bad input.
Prints `ark game: ok`.

## Resolved Grill Log

- **Q:** Exercise the loop through a window? **A:** No; `step` takes time and events as values,
  so the fixture is deterministic and needs no display.

## Referenced by

[[Ark Game]] · [[Ark Game Camera]] · [[Ark Game Gate]] · [[src/Ark/_MOC]]
