---
type: module
path: "@root/test/Pudu/Backend/AppSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, native, mobile, ios]
aliases: [Native App Tests]
---

# Native App Tests

## Purpose

Evidence for the pure parts of [[Backend Toolchain App]]: the bundle identifier
derived from a program's name, and the property list written into the bundle.

## Cases

| Case | Kind | Evidence |
| --- | --- | --- |
| application identifiers derive from the program's name | success | `Counter` gives `org.pudu.Counter`; `my-app.v2` keeps its hyphen and dot; `Café Lists` replaces the non-ASCII letter and the space with `-`, giving `org.pudu.Caf--Lists` |
| application property lists name the bundle and escape their text | success, output | the identifier, the executable `A&amp;B` for the name `A&B`, package type `APPL`, minimum system `15.0`, the `iPhoneSimulator` platform, an empty launch screen, a true Boolean ProMotion opt-in, and no unescaped ampersand |

## Grill Log

- **Q:** Why test only the pure parts here?
  **A:** Building and launching an application needs the platform SDK and a
  simulator. `test/ios-simulator.mjs` builds every example with `pudu build --app`
  and launches it, so the end-to-end path is covered there. _Rationale:_ the
  identifier and the property list are pure text, and they can be checked on any
  machine without a toolchain.

- **Q:** Can the simulator test establish 120 Hz presentation? **A:** It can verify the bundle
  property type and value. Frame-rate evidence comes from a physical display.

## Referenced by

[[Backend Toolchain App]] · [[Native App Delivery]]
