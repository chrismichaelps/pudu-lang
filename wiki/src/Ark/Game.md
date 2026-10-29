---
type: module
path: "@root/lib/Ark/Game.pudu"
fidelity: Active
aliases: [Ark Game]
tags: [module, ark, game]
---

# Ark Game

## Purpose and interface

`Scene[S]` pairs three hooks over a game-defined state `S`: `fixed(state, seconds)` for each owed
fixed step, `update(state, frame)` once per displayed frame with this frame's input, action map
and clock tick, and `draw(state, alpha, target)` with the fraction of a step still owed for
interpolation. Any hook answering None ends the game. `Active[S]` pairs a scene with its state.

`start(first, actions, stepNanos, maxSteps, now)` builds an `App[S]` over [[Ark Frame Clock]];
`step(app, events, now)` applies [[Ark Input]] events, runs the owed fixed steps (capped by the
step budget) and the update on the top scene only; `change` applies `Stay`, `Push`, `Pop`,
`Replace` or `Quit`; `draw` draws the top scene; `top` and `finished` inspect the app. `run(app,
window, maxFrames)` is the windowed loop over [[Ark Window]] with the monotonic clock.

## Invariants

- Every step is a value transformation, so whole sessions replay headlessly with chosen times.
- Scenes below the top are paused: neither their clocks nor their states advance.
- A finished app is a fixed point of `step`.

## Resolved Grill Log

- **Q:** Make scenes trait objects? **A:** No; a record of hook functions over a type parameter
  keeps dispatch flat and lets the fixture build scenes from plain functions.
- **Q:** Let the loop call the wall clock itself? **A:** Only in `run`; `step` takes `now`, so tests
  and replays decide time.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Game Camera]] · [[Ark Game Fixture]] · [[Ark Game Gate]]
