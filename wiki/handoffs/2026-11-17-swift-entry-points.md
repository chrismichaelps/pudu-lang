---
type: handoff
status: ACTIVE
issue: 881
aliases: [Swift Entry Points Delivery]
---

# Swift Entry Points Delivery

Swift needs no separate interface. A Swift library exposes `@_cdecl` functions, which cross
into Pudu as ordinary C functions through the existing foreign block.

## Design

- Owned objects: the Swift side returns `Unmanaged.passRetained` handles. A declared release
  function balances the retain, and a double release is refused with `E7022`.
- Callbacks: a C function pointer marked `@convention(c)` plus an opaque context pointer.
- No compiler change was made.

## Evidence

- macOS check: [[Swift Entry Points Test]] passes with `swiftc`; interpreted and native output
  match, and the double release is refused identically.
- iOS simulator run on iOS 26.4: [[iOS Foreign Apps Test]] passes the `swiftSmoke` case, using
  an embedded framework with an `@rpath` install name.

## Exact next action

Open the #881 PR to dev after #944 merges, then start #880 JNI bindings.
