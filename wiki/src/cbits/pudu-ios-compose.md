---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_compose.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, compose]
aliases: [pudu-ios-compose, iOS Host Compose]
---

# pudu-ios-compose

## Purpose and interface

The system sheets of the iOS host (#994): the share sheet for a file, the review request, the calendar event editor, and the mail and message composers. Included once by [[iOS Host Adapter]]. It implements the handlers of instructions SHARE_FILE (86), REVIEW (87), ADD_EVENT (88), COMPOSE_MAIL (89) and COMPOSE_MESSAGE (90) of [[Std Mobile Request]]. Its reports are SHARED (26), which is queued by [[pudu-ios-system]], and COMPLETED (47) of [[Std Mobile Events]], both queued through [[iOS Host Events]]. StoreKit, EventKit, EventKitUI and MessageUI are linked always.

## Behavior

- SHARE_FILE presents a UIActivityViewController with the file's URL. SHARED is queued from its completion with detail 1 when an activity completed and 0 when the sheet closed.
- REVIEW asks StoreKit for the App Store review prompt in the active window scene. It queues nothing, and the platform may decline to show the prompt.
- ADD_EVENT creates an EKEvent in an EKEventStore with the start, end, title and location, and presents an EKEventEditViewController. COMPLETED is queued with detail 1 when the event is saved and 0 when the editor is cancelled.
- COMPOSE_MAIL presents an MFMailComposeViewController addressed to the recipients. COMPLETED is queued with detail 1 when the mail is sent and 0 when it is cancelled or fails. A device that cannot send mail queues COMPLETED 0 at once.
- COMPOSE_MESSAGE presents an MFMessageComposeViewController with the recipients and body. It follows the same rule as mail.

## Invariants

- Each sheet queues exactly one answer under its tag.
- The event store and each controller are released after their answer is queued.
- The start and end arrive as two words, high then low, and are converted to a date once, in this header.

## Negative Logic

- No calendar read. The editor creates the event; the host never fetches events from the store.
- No review outcome. REVIEW reports nothing, because iOS never says whether the prompt appeared.
- No mail or message is sent without the person pressing send in the platform composer.
- No file copy. SHARE_FILE shares the URL that the program supplies.

## Dependencies and consumers

Depends on StoreKit (the review request), EventKit (EKEventStore and EKEvent), EventKitUI (EKEventEditViewController), MessageUI (MFMailComposeViewController and MFMessageComposeViewController), UIKit (UIActivityViewController), [[iOS Host Events]] for the queue, [[pudu-ios-system]] for SHARED, and [[pudu-ios-kinds]] for the instruction tables. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Compose]], [[Std Mobile System]], [[Std Mobile Request]] and [[Std Mobile Events]]. Its example is [[Outbox Example]]. Its Android counterpart is [[PuduCompose]].

## Resolved Grill Log

- **Q:** Why does the event editor need no calendar permission? **A:** EventKitUI runs the editor outside the application, and the person chooses where the event is saved. The application never reads the store.
- **Q:** Why does REVIEW report nothing? **A:** StoreKit decides whether the prompt appears and never reports that decision. A reply would claim a state the host cannot know.
- **Q:** Why does a device that cannot send mail answer at once? **A:** The composer cannot be presented, so the host answers 0 rather than wait for a sheet that will never appear.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Compose]] · [[Std Mobile System]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[pudu-ios-system]] · [[Outbox Example]] · [[PuduCompose]] · [[NATIVE-MOBILE]]
