---
type: handoff
status: ACTIVE
issue: 973
aliases: [Native Images Delivery]
---

# Native Images Delivery

Implementer owns the native image and application asset work: images on the iOS and Android hosts, the image stream and report, and the packaging of the `assets` directory. Role transition: the Language Architect owns the public contract in [[Std Mobile Control]], [[Std Mobile Stream]] and [[Std Mobile Events]]; the Implementer takes the contract as fixed. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

Instruction SOURCE 45, kind IMAGE 22, and event IMAGED 24 on the iOS and Android hosts. Application assets packaged from the `assets` directory beside the entry module, with refusal E6013. Numbering as in [[NATIVE-MOBILE]].

## Owned files

- `cbits/pudu_ios_image.h`, `cbits/pudu_ios_kinds.h`, `cbits/pudu_ios_host.m`
- `android/org/pudu/PuduImage.java`, `android/org/pudu/PuduBridge.java`, `android/org/pudu/PuduActivity.java`
- `src/Pudu/Backend/Toolchain/Assets.hs`, `src/Pudu/Backend/Toolchain/App.hs`, `src/Pudu/Backend/Toolchain/Android.hs`
- `lib/Std/Mobile/{Control,Stream,Events,View}.pudu`, `examples/mobile/Gallery.pudu`, `examples/mobile/assets/pudu.png`, `test/fetch-server.mjs`

## Simulator and device refusals

Each refusal listed in [[pudu-ios-image]] is a stream defect that leaves the image unchanged. Each name or link refused by [[Backend Toolchain Assets]] stops the build before anything is packaged. Neither the Android image path nor the Android asset packaging has run on a device or emulator.

## Exact next action

Run the Gallery example on an Android emulator or device, and record its labels, its image sizes and the single request for the photo in [[Gallery Example]].

## Referenced by

[[handoffs/_MOC]] · [[pudu-ios-image]] · [[PuduImage]] · [[Gallery Example]] · [[Backend Toolchain Assets]] · [[Uses Mobile Image]] · [[NATIVE-MOBILE]] · [[Std Mobile Stream]]
