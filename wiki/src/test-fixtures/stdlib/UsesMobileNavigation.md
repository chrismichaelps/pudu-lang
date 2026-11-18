---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileNavigation.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, navigation]
aliases: [Uses Mobile Navigation]
---

# Uses Mobile Navigation

## Purpose and interface

Stdlib fixture for [[Std Mobile Navigation]]. Its entry drives `mount`, `update`, `observe` and `kept` through the checks below and answers the number of checks that held: 19. The data spec [[Pudu Compiler Program Eval Data Spec]] asserts that count. It also decodes the two new kinds through [[Std Mobile Events]].

Checks, each comparing an exact word sequence or byte length:
- Mount: the root body is label node 0 with the text "a", then NAVIGATE with one route, id 1, body node 0 and the title "Home", and no sheet. The mounted stream is 53 bytes.
- Push: the root keeps its body, the new page builds label 1, and NAVIGATE names both routes. The stream is 66 bytes.
- An unchanged presentation writes nothing.
- A body edit writes the TEXT of the page's label and no NAVIGATE, 13 bytes.
- A title edit writes NAVIGATE alone, 41 bytes.
- A user pop the program applies removes the popped page's subtree, frees its id, and sends no NAVIGATE: 16 bytes, with id 1 freed.
- A user pop the program refuses sends the whole stack again: 41 bytes.
- A stale pop, one whose top is not current, leaves `shown` unchanged.
- `kept` answers how many routes survive a reported pop: `Some(1)` for a pop from 2 to 1 in [1, 2] and from 3 to 1 in [1, 2, 3].
- `kept` answers None for a stale top, for a stack of one route, and for a destination not below the top.
- A programmatic pop removes the page and sends NAVIGATE with the root alone: 44 bytes.
- Another route at the same place ends the old page and reuses its freed id: 82 bytes, with the new route's id in the NAVIGATE.
- A sheet: its body is built, then NAVIGATE ends with 1, the sheet's id 9 and its body node 1: 61 bytes.
- A user dismissal the program applies removes the sheet's body with no NAVIGATE: 16 bytes.
- A stale dismissal, for an id that is not the shown sheet, leaves the sheet shown and resends NAVIGATE: 44 bytes.
- `Events.eventWithDetail` of kind 14 with tag 2 and detail 1 is `Popped(2, 1)`, and `carriesDetail` of kind 14 is true.
- `Events.event` of kind 15 with tag 9 is `Dismissed(9)`, and `carriesDetail` of kind 15 is false.

## Invariants

- The fixture uses the pure interface of [[Std Mobile Navigation]] and [[Std Mobile Events]]. It makes no foreign call and needs no simulator.
- Each check is one `if` that adds one to the count. A failed check does not stop the others.

## Negative Logic

- No host applies the streams. The fixture checks the words the program writes, not what the platform shows.
- No duplicate-id refusal is checked here. The host refuses a repeated id, and the simulator run checks that refusal.

## Dependencies and consumers

Depends on [[Std Mobile Navigation]], [[Std Mobile Events]], [[Std Mobile View]] and the byte-order helper of `Std.ByteOrder`. Consumer: the data spec [[Pudu Compiler Program Eval Data Spec]]. Its page-level counterpart is [[Native Pages Example]].

## Resolved Grill Log

- **Q:** Check the stream as words and bytes or as a summary? **A:** As words and bytes, because the host decodes the words. A length alone would pass a wrong instruction.
- **Q:** Why check the stale pop and the stale dismissal? **A:** A report about a presentation the program no longer shows must change nothing, and the next update must restore the navigation the program holds.

## Referenced by

[[Std Mobile Navigation]] · [[Native Pages Example]] · [[Uses Mobile View]]
