---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduCompose.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, compose]
aliases: [PuduCompose]
---

# PuduCompose

## Purpose and interface

The system sheets of the Android host (#994): sharing a cached file, the review request, the calendar event insert, and the mail and message intents. The class is called from [[PuduBridge]] for SHARE_FILE, REVIEW, ADD_EVENT, COMPOSE_MAIL and COMPOSE_MESSAGE, through the handlers registered in [[pudu-android-services]]. Its reports are SHARED (26) and COMPLETED (47) of [[Std Mobile Events]]. The handlers run on the main thread. File URIs come from [[PuduFiles]].

## Behavior

- SHARE_FILE builds a content URI for the file through [[PuduFiles]], then starts ACTION_SEND with that URI and a read grant. SHARED is sent with detail 1 once the chooser opens. A path outside the cache directory is not shared, and SHARED is sent with detail 0.
- REVIEW is ignored. The platform prompt needs a store library, which the package does not include.
- ADD_EVENT starts ACTION_INSERT on CalendarContract.Events with the begin and end times in milliseconds and the title and location extras. COMPLETED is sent with detail 1 once the editor opens, and 0 when no calendar application handles the intent.
- COMPOSE_MAIL starts ACTION_SENDTO with a `mailto:` URI and the recipients, subject and body as extras. COMPLETED is sent with detail 1 once it opens, and 0 when nothing handles it.
- COMPOSE_MESSAGE starts ACTION_SENDTO with an `smsto:` URI, the recipients in the URI and the body in `sms_body`. It follows the rule of mail.

## Invariants

- Each request sends exactly one answer under its tag.
- A file is shared only through a URI that [[PuduFiles]] serves. The class never builds a `file:` URI.
- The begin and end times are computed as 64-bit milliseconds from the signed seconds sent by the program.

## Negative Logic

- No outcome after an intent opens. COMPLETED 1 means the sheet opened, not that the event was saved or the mail was sent.
- No store library and no review prompt.
- No direct send. Mail and messages go through the application the person already uses.
- No shared file outside the cache directory.

## Dependencies and consumers

Depends on ACTION_SEND, ACTION_INSERT on CalendarContract.Events, ACTION_SENDTO for `mailto:` and `smsto:`, the package manager's check that an activity handles each intent, [[PuduFiles]] for the URI, and [[PuduBridge]] for the call. Called by [[PuduBridge]]. Its counterpart on iOS is [[pudu-ios-compose]]. Program side: [[Std Mobile Compose]], [[Std Mobile System]] and [[Std Mobile Request]]. Example: [[Outbox Example]].

## Resolved Grill Log

- **Q:** Why does COMPLETED 1 mean the editor opened? **A:** An intent handed to another application does not report its outcome to this one. The program that needs the saved event must not rely on that answer on this host.
- **Q:** Why is the file shared through a provider and not a file URI? **A:** Android refuses file URIs across applications. A provider with a read grant lets the receiving application read one named file for the length of the share.
- **Q:** Why is REVIEW ignored here? **A:** The platform prompt needs a store library the package does not include, so there is no prompt to show.

## Referenced by

[[PuduBridge]] · [[PuduActivity]] · [[pudu-android-services]] · [[PuduFiles]] · [[pudu-ios-compose]] · [[Std Mobile Compose]] · [[Outbox Example]] · [[NATIVE-MOBILE]]
