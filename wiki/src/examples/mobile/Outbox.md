---
type: module
path: "@root/examples/mobile/Outbox.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, compose]
aliases: [Outbox Example]
---

# Outbox Example

## Purpose and interface

A program that exercises the system sheets (#994) in one screen: sharing a file from the cache directory, the review prompt, a calendar event, a mail and a message. The screen shows one button for each request and a label for each answer:
- `Share: <none, done or cancelled>`: the SHARED answer for the shared file.
- `Event: <none, done or cancelled>`: the COMPLETED answer of the calendar sheet.
- `Mail: <none, done or cancelled>`: the COMPLETED answer of the mail sheet.
- `Message: <none, done or cancelled>`: the COMPLETED answer of the message sheet.

The review request has a button and no label, because it reports nothing. The program uses [[Std Mobile Compose]] for the calendar, mail and message sheets, [[Std Mobile System]] for sharing and the review prompt, [[Std Mobile View]] for the tree and events, and [[Std Mobile Host]] for the apply and wait calls.

## Simulator expectations

The iOS suite runs the program with no self-test interaction, and checks its labels at rest: every label reads `none`. The package declares no permissions, because none of the sheets needs one.

## Invariants

- Each label is computed from the model, which changes only by events.
- The program never decides an answer. A label shows what the host reports: `done` for 1 and `cancelled` for 0.
- The shared file is a file in the cache directory, never a file the program has not written.

## Negative Logic

- No calendar, mail or message read. Each sheet is an editor the person completes.
- No retry after a cancellation. The sheet is not reopened.
- No stored state. The labels are rebuilt from events each run.

## Dependencies and consumers

Depends on [[Std Mobile Compose]], [[Std Mobile System]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Mobile Lifecycle]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-compose]] and [[pudu-ios-system]], and the Android host with [[PuduCompose]] and [[PuduFiles]]. Its fixture-level counterpart is [[Uses Mobile Compose]].

## Resolved Grill Log

- **Q:** Why are the labels checked at rest only? **A:** Each sheet needs a person to complete it, and the simulator suite runs without interaction. Only the starting state is fixed.
- **Q:** Why does the example declare no permissions? **A:** The event editor, the composers and the share sheet need none, so the platform asks nothing at first use.
- **Q:** Why does a `cancelled` label stay rather than clear? **A:** A cleared label looks like a lost answer. `cancelled` shows that the host reported the cancellation.

## Referenced by

[[src/examples/_MOC]] · [[Std Mobile Compose]] · [[Std Mobile System]] · [[Std Mobile Events]] · [[pudu-ios-compose]] · [[PuduCompose]] · [[PuduFiles]] · [[Uses Mobile Compose]] · [[NATIVE-MOBILE]]
