---
type: handoff
status: ACTIVE
issue: 994
aliases: [Native Compose]
---

# Native Compose

Implementer owns the #994 slice: sharing a cached file, the review prompt, calendar events, mail and messages. The instruction codes 86 to 90 in [[Std Mobile Request]], and the event 47 in [[Std Mobile Events]], are taken as fixed for this slice; the instruction bound is 91. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

[[Std Mobile Compose]], [[Std Mobile Request]], [[Std Mobile System]], [[Std Mobile Events]] and [[Std Mobile View]]; the iOS host ([[pudu-ios-compose]]); the Android host ([[PuduCompose]] and [[PuduFiles]]); the example [[Outbox Example]]; the stdlib fixture [[Uses Mobile Compose]].

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Compose.pudu`, `Request.pudu`, `System.pudu`, `Events.pudu`, `View.pudu`
- `packages/pudu/v0.1/cbits/pudu_ios_compose.h`
- `packages/pudu/v0.1/android/org/pudu/PuduCompose.java` and `PuduFiles.java`
- `examples/mobile/Outbox.pudu`
- `test-fixtures/stdlib/UsesMobileCompose.pudu`
- Shared files edited by this slice: `cbits/pudu_ios_host.m`, `pudu_ios_nodes.h`, `pudu_ios_events.h`, `pudu_android_services.h`, the application manifest's provider declaration, the toolchain framework and source lists, `test/ios-simulator.mjs`, `test/Pudu/Compiler/Program/Eval/DataSpec.hs`

## Known limits

The Android path has not run on a device or an emulator. Its evidence is the source of [[PuduCompose]] and [[PuduFiles]]. On Android, COMPLETED 1 means the sheet opened, not that the event was saved or the mail was sent. The iOS self-test checks the example's labels at rest only, so the suite does not exercise the sheets themselves.

[[Std Mobile View]] is at its line limit; the next event needs #993 (constructors through a type alias) or a split of the reconciler.

## Exact next action

Run [[Outbox Example]] on an Android device: share a cached file, add an event, open mail and messages.

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Compose]] · [[Std Mobile Request]] · [[Std Mobile System]] · [[Std Mobile Events]] · [[Std Mobile View]] · [[Outbox Example]] · [[Uses Mobile Compose]] · [[pudu-ios-compose]] · [[PuduCompose]] · [[PuduFiles]] · [[NATIVE-MOBILE]]
