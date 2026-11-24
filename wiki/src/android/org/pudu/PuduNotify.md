---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduNotify.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, notification]
aliases: [PuduNotify]
---

# PuduNotify

## Purpose and interface

Local notifications on the Android host (#989). The class is called from [[PuduBridge]] when a NOTIFY or UNNOTIFY instruction arrives, through the handlers registered in [[pudu-android-services]]. A tap is reported as NOTIFIED (35) of [[Std Mobile Events]]. The handlers run on the main thread.

## Behavior

- A single notification channel is created on API 26 and later. Older platforms need no channel.
- NOTIFY sets an alarm with AlarmManager using the inexact `set` call. When the alarm fires, [[PuduAlarm]] posts the notification. A delay of 0 or less posts at once.
- A notification with an id that is already scheduled replaces the earlier one. UNNOTIFY cancels the alarm and removes the posted notification with that id.
- A tap opens [[PuduActivity]] with the extra `org.pudu.notified` holding the id. The activity reports it from the launch intent or from a new intent.

## Invariants

- Each id maps to one alarm and at most one posted notification.
- Alarm and notification identifiers come from the program's id, so a cancel names the notification a schedule created.

## Negative Logic

- No exact alarm. The inexact call is used because exact alarms need a special permission on newer versions; a reminder minutes late is accepted.
- No permission request. The notifications permission is requested by the permission module.
- No delivery report. Only a tap is reported.

## Dependencies and consumers

Depends on NotificationManager, AlarmManager, the notification channel API and the activity intent. Called by [[PuduBridge]]; the alarm receiver is [[PuduAlarm]]; the activity is [[PuduActivity]]. Its iOS counterpart is [[pudu-ios-notify]]. Program side: [[Std Mobile Notify]].

## Resolved Grill Log

- **Q:** Why is the alarm inexact? **A:** Exact alarms need a special permission on newer versions. A local reminder a few minutes late is acceptable, and the permission would be a cost to every program for no gain.
- **Q:** Why does a tap carry the id as an extra? **A:** The activity must report which notification was tapped, including a tap that launched the app. The extra survives the launch and the new-intent path alike.
- **Q:** Why one channel? **A:** The notifications of one program share one purpose. A channel per id would add a setting the person must manage with no use.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduBridge]] · [[PuduAlarm]] · [[PuduActivity]] · [[pudu-android-services]] · [[pudu-ios-notify]] · [[Std Mobile Notify]] · [[NATIVE-MOBILE]]
