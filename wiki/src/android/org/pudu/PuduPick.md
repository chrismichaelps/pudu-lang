---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduPick.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, pick, media]
aliases: [PuduPick]
---

# PuduPick

## Purpose and interface

The contact, document and photo pickers, audio recording, the secure screen setting and toasts of the Android host (#991). The class is called from [[PuduBridge]] for PICK_CONTACT, PICK_DOCUMENT, TAKE_PHOTO, RECORD, SECURE and TOAST, through the handlers registered in [[pudu-android-services]]. Its results return to [[PuduActivity]], whose `onActivityResult` routes each request code to this class. Its reports are CONTACT_PICKED (45) and FILED (46) of [[Std Mobile Events]]. The handlers run on the main thread.

## Behavior

- PICK_CONTACT starts an ACTION_PICK on the phone contacts content. The returned URI is read through the grant it carries, and the name, numbers and addresses are sent as CONTACT_PICKED with detail 1. A cancelled pick sends detail 0 with empty text.
- PICK_DOCUMENT starts ACTION_OPEN_DOCUMENT with the MIME types as filters. The chosen file is copied into the cache directory, capped in size as images are, and sent as FILED with its path.
- TAKE_PHOTO starts ACTION_IMAGE_CAPTURE. The returned thumbnail bitmap is saved as JPEG in the cache directory and sent as FILED. A cancelled capture or a missing camera sends FILED with detail 0.
- RECORD on 1 starts a MediaRecorder with AAC in MPEG-4 into the cache directory. RECORD on 0 stops it and sends FILED with the file's path.
- SECURE sets or clears FLAG_SECURE on the window. Screenshots and screen recordings of the window are blocked while it is set.
- TOAST shows an android.widget.Toast with the text.
- BADGE is ignored. Launchers derive badges from posted notifications, and there is no portable count API.

## Invariants

- Each picker request sends exactly one answer under its tag.
- A picked content URI is accepted only when its authority has no `@` and `PackageManager.resolveContentProvider` resolves it to a provider of another package (`PuduPick.foreign`, used by both this class and [[PuduMedia]]), so a result cannot read this application's own private files through a returned URI.
- A picked contact row must come from the system contacts authority under the phone table's path.
- A recorder is released when it stops, and a recorder under a new RECORD on 1 replaces none still running.

## Negative Logic

- No contacts permission. The picker returns only what the person chose.
- No badge count. BADGE does nothing on this host.
- No secure-screen state kept across activities. The flag belongs to the window it is set on.
- No file bytes on the stream. Files are reported by path.

## Dependencies and consumers

Depends on the system pickers (ACTION_PICK, ACTION_OPEN_DOCUMENT and ACTION_IMAGE_CAPTURE), MediaRecorder, WindowManager (FLAG_SECURE), android.widget.Toast, the request-code routing of [[PuduActivity]] and the content resolver, and [[PuduBridge]] for the call. Called by [[PuduBridge]]. Its counterpart on iOS is [[pudu-ios-pick]]. Program side: [[Std Mobile Pick]], [[Std Mobile System]] and [[Std Mobile Request]]. Example: [[Picker Example]].

## Resolved Grill Log

- **Q:** Why are picked files copied into the cache directory? **A:** A grant on a returned URI can lapse when the activity ends. The copy belongs to the application, so the program can read it after the picker closes.
- **Q:** Why is BADGE ignored on Android? **A:** Launchers show badges from posted notifications. There is no portable API that sets a count, so a count set here would not appear reliably.
- **Q:** Why are content URIs accepted only from other providers? **A:** A result from this application's own provider would expose its private files to whatever app returned the URI. The check keeps the picker path from becoming a read of private data.

## Referenced by

[[PuduBridge]] · [[PuduActivity]] · [[pudu-android-services]] · [[pudu-ios-pick]] · [[Std Mobile Pick]] · [[Picker Example]] · [[NATIVE-MOBILE]]
