---
type: module
path: "@root/src/Pudu/Doc/Json.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.6
tags: [module, shallow]
aliases: [Doc Json]
---

# Doc Json

## Purpose

Emit the documentation index in the shape an editor or a search server consumes.

## Interface

### Signatures

```haskell
encodeIndex :: DocIndex -> Text
encodeEntry :: DocEntry -> Text
escapeJson :: Text -> Text
```

### Governance

- The encoding is written by hand rather than pulled from a library. The shape is small, fixed, and
  part of this project's public contract with editors; a dependency would put that contract in
  someone else's release schedule for no expressive gain.
- Every entry carries both the rendered signature and its structure. An editor showing a hover
  wants the rendering; a search server indexing many programs wants the structure, and asking it to
  re-parse the rendering would make the renderer part of the protocol.
- Every type node carries its own rendered form beside its structure, so a consumer displaying one
  fragment never reimplements rendering.
- Scalars below U+0020 are escaped numerically rather than dropped: the index is generated from
  source a reader wrote, and silently losing a scalar would make the output disagree with the file
  it describes.

### Linkage

- **Requires:** [[Doc Index]], [[Doc Signature]].
- **Consumed by:** [[Program Cli]].

## Algorithm

Direct structural encoding, with objects and arrays assembled by `Text.intercalate`.

## Negative Logic (Prohibited Paths)

- No pretty-printing, no key reordering, and no omission of empty fields: a consumer parses this,
  and a stable shape is worth more than a compact one.
- No dependency on a JSON library for a contract this small.

## Edge Cases

- An entry with no signature encodes `null` for both the rendering and the structure, so a consumer
  never has to distinguish "absent" from "empty".

## Depth

DEPTH 0.30 (SHALLOW by intent). It is a serializer.

## Grill Log

- **Q:** Should the output include a schema version? **A:** Not yet. _Rationale:_ there is exactly
  one consumer contract and no released tool depending on it; adding a version now would record a
  compatibility promise the project has not yet made. _Deferred:_ revisit when an editor extension
  ships against it.

## Referenced by

[[src/Pudu/Doc/_MOC]] · [[Doc Index]]
