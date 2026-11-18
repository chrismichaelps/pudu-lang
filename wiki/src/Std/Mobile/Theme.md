---
type: module
path: "@root/lib/Std/Mobile/Theme.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Theme]
---

# Std Mobile Theme

## Purpose and interface

Pure theme value of the mobile stack. It names the color roles a screen uses, the text styles of its text, and the appearance it is drawn in, and it encodes that choice as one THEME and one APPEARANCE instruction of [[Std Mobile Stream]]. The host turns the tones into platform colors at draw time, so a theme is data and not a resolved palette.

Exports:
- `type Rgba = { red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 }`: sRGB with straight alpha.
- `type Tone = Platform | Fixed(Rgba, Rgba)`: `Platform` uses the platform's own semantic color for the role; `Fixed(light, dark)` gives one color per appearance.
- `type Role = Surface | Ink | Accent | OnAccent | Muted | Danger | Separator`: wire codes 0 to 6 in that order.
- `type Appearance = System | Light | Dark`: wire codes 0, 1 and 2.
- `type TextStyle = LargeTitle | Title | Headline | Body | Callout | Subheadline | Footnote | Caption`: wire codes 1 to 8 in that order. Code 0 is never written.
- `type Theme = { surface: Tone, ink: Tone, accent: Tone, onAccent: Tone, muted: Tone, danger: Tone, separator: Tone, appearance: Appearance }`
- `platform() -> Theme`: every role `Platform`, appearance `System`.
- `rgb(red: UInt8, green: UInt8, blue: UInt8) -> Rgba`: an opaque color.
- `stream(theme: &Theme) -> Bytes`: one THEME instruction with the seven tones in role order, then one APPEARANCE instruction.
- `restyled(before: &Theme, after: &Theme) -> Bytes`: empty when the two encode identically, otherwise `stream(after)`.
- `type Material = Thin | Regular | Thick`: wire codes 1, 2 and 3 in that order. Code 0 is never written.
- `roleCode(role: Role) -> UInt32`, `styleCode(style: TextStyle) -> UInt32` and `materialCode(material: Material) -> UInt32`: the wire codes, read from constant tables. `materialCode` reads the constant table `MATERIALS`.

## Invariants

- Pure: the module declares no foreign function and performs no I/O.
- Codes come from the constant `Map` tables `ROLES`, `STYLES` and `APPEARANCES`. No code is chosen by an if-ladder or a match.
- A tone is written as three words: its kind (0 for `Platform`, 1 for `Fixed`), the light color word and the dark color word. A color word packs `red | green << 8 | blue << 16 | alpha << 24`, so its little-endian bytes are R, G, B, A.
- `Platform` writes zero color words.
- `stream` writes the seven tones in role order, so the THEME count word is 7 and the APPEARANCE instruction follows it.

## Negative Logic

- The module never resolves a color for an appearance. The host does, at draw time.
- No Oklch and no CSS. Design-token conversion to sRGB happens once, in the token package of FUI, before a value reaches this module.
- A theme change is a separate commit, applied with `Std.Mobile.Host` `apply`. It is never part of a view update, so `View.mount` and `View.update` emit no theme instruction.
- No string-keyed tokens on the wire. Roles are a closed sum.
- A material is a code only. The host chooses its realization (glass or blur) at draw time; this module names no platform view.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the instruction words. Consumers: [[Std Mobile View]], which uses `Role`, `TextStyle` and `Material` in its wrappers; the host [[iOS Host Theme]]; the host [[iOS Host Material]]; the fixtures [[Uses Mobile Theme]] and [[Uses Mobile Material]]; and the examples [[Native Themed Example]] and [[Native Glass Example]].

## Resolved Grill Log

- **Q:** Resolve light and dark in Pudu and resend on every appearance change? **A:** No. The host turns a fixed pair into a dynamic platform color, so an appearance change costs no Pudu work and no crossing. _Rejected:_ reporting each trait change and rebuilding the tree.
- **Q:** Why keep a Platform tone? **A:** An app without a design system should look exactly like the platform, including accessibility contrast variants the platform colors carry. _Rejected:_ shipping hard-coded approximations of platform colors.
- **Q:** Why sRGB bytes rather than perceptual coordinates? **A:** The host draws in sRGB; conversion belongs once in the token package, not in every frame. _Rejected:_ Oklch on the wire.
- **Q:** Why a fixed role set rather than arbitrary named tokens? **A:** Platform controls consume a small number of semantic slots; a closed sum is exhaustive and cheap to encode. _Rejected:_ string-keyed tokens on the wire.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[iOS Host Theme]] · [[iOS Host Material]] · [[Native iOS Theming Delivery]] · [[Native iOS Materials Delivery]]
