---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduAlarm.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, notification]
aliases: [PuduAlarm]
---

# PuduAlarm

## Purpose and interface

The broadcast receiver that posts a scheduled local notification on the Android host (#989). AlarmManager starts it when an alarm set by [[PuduNotify]] fires. It is declared in the manifest, not exported, so no other application can start it.

## Behavior

- On receipt, the receiver reads the id and the title and body text from the alarm's extras and posts a notification through the channel created by [[PuduNotify]].
- The notification's content intent opens [[PuduActivity]] with the extra `org.pudu.notified` holding the id.
- A receipt without an id posts nothing.

## Invariants

- The posted notification uses the same identifier as the alarm that started it, so UNNOTIFY can remove it.
- The receiver holds no state between receipts.

## Negative Logic

- No export. The manifest entry is not exported, so the receiver cannot be started by another application.
- No scheduling. The receiver posts only; scheduling belongs to [[PuduNotify]].
- No wake lock. The receiver does the posting within the receipt.

## Dependencies and consumers

Depends on BroadcastReceiver, NotificationManager and the intent extras. Started by AlarmManager on behalf of [[PuduNotify]]. Declared in the manifest beside [[PuduActivity]]. Program side: [[Std Mobile Notify]].

## Resolved Grill Log

- **Q:** Why is the receiver not exported? **A:** Only the alarms the program set should post notifications. An exported receiver would let any application post into the program's channel.
- **Q:** Why does the receiver post rather than the alarm itself? **A:** An alarm carries no notification. The receiver builds the notification from the alarm's extras at the moment it fires.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduNotify]] · [[PuduActivity]] · [[pudu-android-services]] · [[NATIVE-MOBILE]]
