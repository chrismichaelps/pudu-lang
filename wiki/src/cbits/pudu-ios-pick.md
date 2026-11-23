---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_pick.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, pick, media]
aliases: [pudu-ios-pick, iOS Host Pick]
---

# pudu-ios-pick

## Purpose and interface

Contact, document and photo pickers, audio recording, the application badge, the secure screen setting and toasts of the iOS host (#991). Included once by [[iOS Host Adapter]], after the web header. It implements the handlers of instructions PICK_CONTACT (79), PICK_DOCUMENT (80), TAKE_PHOTO (81), RECORD (82), BADGE (83), SECURE (84) and TOAST (85) of [[Std Mobile Request]]. Its reports are CONTACT_PICKED (45) and FILED (46) of [[Std Mobile Events]], queued through [[iOS Host Events]]. ContactsUI, Contacts and UniformTypeIdentifiers are linked always, alongside AVFoundation.

## Behavior

- PICK_CONTACT presents a CNContactPickerViewController. A chosen contact queues CONTACT_PICKED with detail 1 and the three-line text of [[Std Mobile Pick]]. A dismissed picker queues detail 0 with empty text.
- PICK_DOCUMENT presents a UIDocumentPickerViewController with `asCopy` set. The MIME types are mapped to UTTypes; an empty list accepts any type. The chosen file is copied into the temporary directory and queues FILED with detail 1 and its path.
- TAKE_PHOTO presents a UIImagePickerController with the camera source. The captured image is written as JPEG to the temporary directory and queues FILED with its path. A device without a camera queues FILED with detail 0.
- RECORD on 1 starts an AVAudioRecorder writing AAC into an `.m4a` file in the temporary directory, under a play-and-record audio session. RECORD on 0 stops it and queues FILED with the file's path.
- BADGE sets the application icon badge through UNUserNotificationCenter when notifications are declared; otherwise it does nothing. A count of 0 clears the badge.
- SECURE is read and ignored. iOS has no control that hides a screen from capture.
- TOAST shows a rounded label over the root view for about two seconds and then removes it with a fade. It reports nothing.

## Invariants

- Each picker request queues exactly one answer under its tag, with a value or a cancellation.
- A recording is owned by one recorder at a time; RECORD on 1 while one is running is not a second recorder.
- Every reported file lies in the temporary directory.

## Negative Logic

- No contacts store read beyond the chosen contact. The picker presents the person's own choice.
- No secure-screen effect. The setting is accepted and has no effect on iOS.
- No toast queue. A new TOAST replaces the visible label.
- No retained picker or recorder after its answer is queued.

## Dependencies and consumers

Depends on ContactsUI (CNContactPickerViewController), Contacts, UniformTypeIdentifiers (UTType), UIKit (UIDocumentPickerViewController and UIImagePickerController), AVFoundation (AVAudioRecorder and AVAudioSession), UserNotifications (badge), [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the instruction tables. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Pick]], [[Std Mobile System]], [[Std Mobile Request]] and [[Std Mobile Events]]. Its example is [[Picker Example]]. Its Android counterpart is [[PuduPick]].

## Resolved Grill Log

- **Q:** Why is the badge ignored when notifications are not declared? **A:** The badge is drawn through the notification center, which needs the Notifications permission. Without it the platform has no badge to set, and the program is not refused.
- **Q:** Why is the toast drawn by the host? **A:** iOS has no system toast. A fading label matches the platform's own transient messages and needs no permission.
- **Q:** Why is SECURE ignored here? **A:** iOS offers no control that hides a screen from screenshots or recordings, so there is nothing to replace. The program still sends the same stream on both hosts.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Pick]] · [[Std Mobile System]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[Picker Example]] · [[PuduPick]] · [[NATIVE-MOBILE]]
