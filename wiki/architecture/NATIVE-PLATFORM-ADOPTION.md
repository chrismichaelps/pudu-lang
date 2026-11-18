---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, native, mobile, ios, toolchain, ledger]
aliases: [Native Platform Adoption]
---

# Native Platform Adoption

## Purpose

How Pudu Native adopts new OS majors, Xcode and SDK releases, store submission rules and new
devices without waiting for a compiler release and without opaque build failures. The facts
that change with the platform live in one ledger ([[Backend Ledger]]); the tools are asked what
is installed ([[Backend Toolchain Probe]]); a build refuses with the exact fix when the
installed toolchain falls outside the ledger. This page extends [[Pudu Native]] and
[[Pudu Native iOS UI]].

## Principles

| Concern | Rule |
| --- | --- |
| Toolchain floor and tested version | Both are data in one ledger. The floor is the lowest Xcode that may build; the tested version is the newest Xcode the suite has run on. |
| Store rules | Each rule carries its effective date and its source. A rule is enforced only on the date it takes effect. |
| Build preflight | A build checks the installed toolchain before compiling and refuses with the exact fix. No build fails later with an unexplained compiler or linker message for a version reason. |
| Device geometry | Comes only from safe areas, size classes and scene sizes, never from model tables. A new phone needs no compiler release. |
| New platform APIs | Gated twice: the selected SDK must declare the API at build time, and the running OS must have it at run time. Otherwise the call answers `UnsupportedPlatform`, never a crash or a silent no-op. |
| Simulator coverage | The simulator suite runs on one device of every family the newest installed runtime offers, so a new emulator type is exercised as soon as it is installed. |
| Diagnostics | `pudu doctor --native` reports all of the above in one place ([[Pudu CLI Doctor]]). |

## Where a new API enters

| Kind of change | Where it goes | Compiler change |
| --- | --- | --- |
| UI behavior | The private host adapter plus a Std.Mobile view or event ([[iOS Host Adapter]]) | None |
| C-callable framework function | A `foreign "c"` declaration | None |
| Objective-C or Swift-only API | Generated from a Pudu interface declaration once platform FFI lands (#874) | Generator only |

The C11 emitter does not change for a new platform API.

## Adoption steps when a platform release ships

1. Run `pudu doctor --native` with the new Xcode.
2. Run the simulator suite on the new runtime's device families ([[iOS Simulator Run]]).
3. Record the version as tested, and add any new store rule or capability row to the
   ledger in one reviewed change.
4. File a tracking issue for each workaround, and keep a known-issues list per OS major on
   this page.
5. Raise the floor only on the date a store rule takes effect.

## Current ledger (iOS)

| Fact | Value |
| --- | --- |
| Xcode minimum | 26.0 |
| Xcode tested | 26.6 |
| Deployment target | iOS 15.0 |
| App Store rule | Built with Xcode 26 and the iOS 26 SDK, effective 2026-04-28. Source: https://developer.apple.com/news/upcoming-requirements/ |
| App Store minimum deployment target | iOS 13, effective 2026-09-09. Met by 15.0. |
| Capability: glass-material | Needs SDK 26.0. Glass realization of materials on iOS 26 or later ([[iOS Host Material]]) |
| Capability: fold posture | Needs SDK 27.1 (iPhone Duo hinge) |

The App Store minimum deployment target constrains the deployment value, so it is checked as a
fact of the ledger rather than as a store rule.

## First gated capability

Materials are the worked example of both gates for a new platform API ([[iOS Host Material]]). The build-time gate is the SDK: the glass branch is compiled only when the selected SDK declares iOS 26, so an older SDK still compiles. The run-time gate is the OS: on iOS 26 or later the glass branch runs, and on older systems the same material is drawn as a system blur. The ledger row `glass-material` records the SDK requirement. A material the host cannot realize at all is a defect, never a silent no-op.

## Known issues

None recorded for iOS 26.

## Grill Log

- **Q:** Why is the Xcode floor the store floor? **A:** Everything the toolchain emits can
  then be submitted; older toolchains are refused with the fix instead of producing an app
  the store rejects. _Rejected:_ an untested lower floor.
- **Q:** Why warn rather than refuse for an Xcode newer than tested? **A:** New releases
  must keep building on day one; the warning asks for the suite to be run and the version
  recorded.
- **Q:** Why do store rules refuse only device builds? **A:** Only device builds are
  submitted; simulator builds warn.
- **Q:** Why plain-text simulator listings rather than structured output? **A:** The listing
  is parsed by pure, tested functions and the compiler carries no JSON dependency for it.

## Referenced by

[[architecture/_MOC]] · [[Pudu Native]] · [[Pudu Native iOS UI]] · [[Backend Ledger]] · [[Backend Toolchain Probe]] · [[Pudu CLI Doctor]]
