---
type: module
path: "@root/lib/Ark/Assets/Import.pudu"
fidelity: Active
aliases: [Ark Asset Import]
tags: [module, ark, assets]
---

# Ark Asset Import

## Purpose and interface

`Payload` is `Raw(Bytes)`, `Image(Texture)` or `Surface(Material)`; `Material` pairs an albedo
[[Ark Texture Asset]] with a linear RGBA tint. `run(kind, bytes, inputs)` dispatches through a
const importer factory table and receives dependency payloads in declared order; `known(kind)`
lets [[Ark Asset Server]] refuse unknown kinds at declaration.

- `bytes` returns the source unchanged and takes no dependencies.
- `texture` reads the cooked format and takes no dependencies.
- `material` reads four RGBA8 tint bytes over exactly one `Image` dependency.

`cookTexture(texture)` writes the cooked format from checked storage; `None` for invalid storage,
an unknown color space or an extent beyond u32.

### Cooked texture format

Bytes 0–3 are `ARKT`; 4–7 width and 8–11 height as little-endian u32; byte 12 is the color
space (0 linear, 1 sRGB, both directions through const tables); the remainder is packed RGBA8
storage checked by `Texture.rgba8`. Importer failures are descriptive strings that the server
wraps with the asset ID.

## Resolved Grill Log

- **Q:** Infer texture dimensions from the byte count? **A:** No; a square guess is ambiguous.
  Cooked data records its extent and color space explicitly.
- **Q:** Dispatch importers with a match on the kind? **A:** No; a const factory table keeps
  registration flat and unknown kinds a typed declaration error.
- **Q:** Decode tint as sRGB? **A:** No; material parameters are linear values, unlike albedo
  texels whose space is recorded per texture.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Asset Server]] · [[Ark Asset Server Fixture]]
