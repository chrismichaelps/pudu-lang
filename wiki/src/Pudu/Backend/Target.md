---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Target.hs"
fidelity: Active
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain, mobile]
aliases: [Backend Native Target]
---

# Backend Native Target

## Purpose and interface

The closed set of mobile native targets and what each refuses to carry
([[Native Mobile Targets]]). Pure: no process, path or environment.

```haskell
data AppleSdk = AppleSdk { appleSdkName :: !Text, appleTriple :: !Text }
data TargetPlatform = ApplePlatform !AppleSdk | AndroidPlatform
data NativeTarget = NativeTarget { nativeTargetName :: !Text, nativeTargetPlatform :: !TargetPlatform }
data TargetRefusal = TargetRefusal { refusedConstruct :: !Text, refusedReason :: !Text }

nativeTargetNamed :: Text -> Maybe NativeTarget
nativeTargetNames :: [Text]
targetRefusals :: NativeTarget -> Set Text -> [(Text, Maybe Text)] -> [TargetRefusal]
```

## Algorithm and invariants

- One const map from name to target: `ios-arm64` (`iphoneos`,
  `arm64-apple-ios15.0`), `ios-simulator-arm64` (`iphonesimulator`,
  `arm64-apple-ios15.0-simulator`), `android-arm64` and `android-x86_64`
  (reserved, no toolchain fields). `nativeTargetNames` is the map's key order.
- `targetRefusals target parts libraries` takes the emitted unit's selected
  runtime parts and its foreign library names. A const table maps each refused
  base part (`host_children`, `host_signals`, `host_exit`, `host_tls`,
  `host_desktop`, `host_audio`) to its construct and its reason on each
  platform. Every dependent part closes over its base, so the base names it.
- A library name without `/` is kept. On Apple platforms a path is kept only
  under the const prefixes `/System/Library/Frameworks/`, `/usr/lib/`,
  `@rpath/` and `@executable_path/`, with no parent traversal components. On Android every
  path is refused. Version strings are filename fragments and may not contain
  a slash, which would introduce a path through a synthesized candidate.
- Refusals list parts in table order, then libraries in first-seen order, each
  once.

## Negative Logic (Prohibited Paths)

- No target outside the map, no prefix matching on names.
- No refusal decided from C text; the emitter's part set is the input.
- SDK discovery belongs to the toolchain.

## Dependencies and consumers

`containers`, `text`. Exercised by [[Backend Native Target Tests]].

## Resolved Grill Log

- **Q:** Why refuse by runtime part rather than by source construct? **A:**
  The part set is exactly what the C would need; a construct list would have
  to repeat the emitter's selection and could drift. _Rejected:_ a second
  walk over Core.
- **Q:** Why reserve Android names with no fields? **A:** The names, the
  diagnostics and the refusals are stable now; the triples and API level arrive
  with the slice that uses them, so no field is unused. _Rejected:_ storing
  the NDK triples ahead of their builder.
- **Q:** Why keep bare library names on iOS? **A:** `dlopen` of a leaf name
  searches the system's own libraries, and `c` is the program itself; neither
  loads code from outside the bundle.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Mobile Targets]]
