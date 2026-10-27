---
type: module
path: "@root/lib/Ark/Platform/Input.pudu"
fidelity: Active
aliases: [Ark Input]
tags: [module, ark, platform]
---
# Ark Input

## Purpose and interface

`Event` is `KeyDown(code, repeat)`, `KeyUp(code)`, `ButtonDown(button, x, y)`,
`ButtonUp(button, x, y)`, `Hover(x, y)`, `Scroll(x, y, delta)`, `Resize(width, height)` or
`Typed(text)`; codes are W3C `KeyboardEvent.code` names. `decode(records)` looks each record's
kind up in the const `EVENT_FACTORIES` table and calls that kind's `EventFactory`; unknown kinds
and malformed records are skipped. Adding a record kind is one table row and one factory. `State` tracks held keys and buttons, this frame's
presses and releases, pointer position, scroll and typed text: `initial`, `beginFrame` (clears
the per-frame sets), `apply(state, events)`, `keyHeld`, `keyPressed`, `keyReleased`,
`buttonHeld`, `buttonPressed`, `buttonReleased`. A repeat is never a press; a press and release
in one frame report both and leave the key up.

`ActionMap` binds action names to `Key(code)` or `Button(n)` bindings: `actions`, `bind`,
`unbind`, `bindingsOf`, `held`, `pressed`, `released` and `axis(map, state, negative,
positive) -> Float64` in {-1, 0, 1}. Gameplay reads actions, never raw keys, so rebinding
needs no code change.

## Grill Log

- **Q:** Dispatch record kinds with an if-ladder? **A:** No; a kind maps to its factory in a
  const table, so kinds are data and each factory validates only its own fields.
- **Q:** Bind to typed characters? **A:** No; characters depend on layout and modifiers.
  Physical codes keep WASD in place on every layout; `Typed` serves text entry.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Platform Fixture]]
