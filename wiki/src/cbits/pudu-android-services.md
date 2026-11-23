---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_android_services.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, android, native, notification, authentication, media, device, jni]
aliases: [pudu-android-services]
---

# pudu-android-services

## Purpose and interface

Private service handlers of the Android host (#989), included once by the Android host translation unit `pudu_android_host.c`. It realizes eleven instructions of [[Std Mobile Stream]]: NOTIFY (63), UNNOTIFY (64), AUTHENTICATE (65), BROWSE (66), SPEAK (67), HUSH (68), BATTERY (69), BRIGHTNESS (70), ORIENTATION (71), SENSE (72) and PICK_IMAGE (73). The numbering is shared with the iOS host ([[pudu-ios-notify]], [[pudu-ios-media]]). The platform work is done on the main thread by [[PuduNotify]], [[PuduAuth]], [[PuduMedia]] and [[PuduDevice]], each reached through [[PuduBridge]]. Routes are registered beside those of [[pudu-android-routes]].

## Behavior

- Each handler reads its request whole, checks it, and only then calls [[PuduBridge]]. A refused request never reaches the platform.
- BRIGHTNESS above 100 is refused with `set brightness to` followed by the value.
- ORIENTATION above 2 is refused with `locked unknown orientation` followed by the code.
- SENSE reads its on word; a value above 1 is refused with `set motion sensing to` followed by the value.
- NOTIFY, UNNOTIFY, AUTHENTICATE, BROWSE, SPEAK, HUSH, BATTERY and PICK_IMAGE carry no refusals beyond malformed text, which the stream reader already rejects.
- Each request whose answer comes later is answered through the event queue under the same tag, as in [[pudu-android-routes]].

## Invariants

- Every check that can refuse an instruction runs before any call that changes the screen, the notification schedule or a sensor.
- Only the program thread reads the request words; the Java side posts to the main thread for every platform change.

## Negative Logic

- No refusal by the platform side for a defect of the program. The platform reports answers, and this header turns defects into stream errors.
- No permission request. The permission module makes the request for notifications and the other kinds.
- No brightness or orientation restore. The platform restores its own when the app leaves the front.

## Dependencies and consumers

Depends on [[pudu_android_events.h]] for the queue, on [[pudu_android_jni.h]] for `pudu_bridge`, `pudu_static` and `pudu_checked`, and on [[pudu-android-routes]] for the shared request conventions. Consumers: the Android host translation unit [[pudu_android_host.c]], which includes this header, and the Java classes [[PuduNotify]], [[PuduAuth]], [[PuduMedia]], [[PuduDevice]] and [[PuduBridge]]. The iOS counterparts are [[pudu-ios-notify]], [[pudu-ios-media]] and [[pudu-ios-device]].

## Resolved Grill Log

- **Q:** Why do the checks live in the header rather than in the platform class? **A:** A defect must be refused before anything changes. The platform side receives only values it can apply, so a refused request leaves the schedule, the window and the sensors as they were.
- **Q:** Why is one request one answer on Android as on iOS? **A:** A program waiting on a tag must always be released. Each handler reports exactly one answer under its tag, including a cancelled prompt.
- **Q:** Why are eleven handlers in one header? **A:** They share one bridge, one queue and one check pattern. Splitting them across headers would repeat the same JNI and refusal code eleven times.

## Referenced by

[[src/cbits/_MOC]] · [[NATIVE-MOBILE]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[pudu-android-routes]] · [[pudu-ios-notify]] · [[pudu-ios-media]] · [[PuduNotify]] · [[PuduAuth]] · [[PuduMedia]] · [[PuduDevice]]
