---
type: module
path: "@root/examples/mobile/Themed.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Themed Example]
---

# Native Themed Example

## Purpose and interface

A program that applies a theme and draws with it on the iOS simulator. It applies a theme whose ink is `Fixed(rgb(0x1f,0x2a,0x44), rgb(0xe8,0xee,0xff))` and whose accent is `Fixed(rgb(0x00,0x66,0xcc), rgb(0x66,0xb2,0xff))`, with appearance `Dark`. It then mounts a column holding `Styled(Body, Label("Themed"))` and the button `Painted(Accent, Button("Done", 1))`. Tapping Done or a stop ends the program.

The simulator run sets `PUDU_UI_THEME_TEST` and expects these lines, as described in [[iOS Simulator Run]]:
- `PUDU_THEME ink light #1F2A44FF dark #E8EEFFFF`
- `PUDU_THEME appearance dark`
- `PUDU_THEME type grows`

On the simulator the app's executable was 264,720 bytes.

## Invariants

- The theme is applied as its own commit, before the mount. A view commit never carries a theme.
- The label and the button are the only controls; the column is a group and takes no style or role.

## Negative Logic

- No color is resolved in Pudu. The light and dark pair reaches the host as data and is resolved by [[iOS Host Theme]] at draw time.
- No event besides Tapped and Stopped is handled.

## Dependencies and consumers

Depends on [[Std Mobile Theme]], [[Std Mobile View]] and [[Std Mobile Host]]. Hosted by [[iOS Host Adapter]] with the theme header [[iOS Host Theme]].

## Resolved Grill Log

- **Q:** Why check the resolved colors and the font size rather than the exit status only? **A:** A theme accepted by the host but never painted would still exit 0. The printed values are the evidence that the paint happened.

## Referenced by

[[src/examples/README]] · [[iOS Simulator Run]] · [[Native iOS Theming Delivery]]
