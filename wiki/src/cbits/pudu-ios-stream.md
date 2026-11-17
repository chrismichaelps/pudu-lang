---
type: module
path: "@root/cbits/pudu_ios_stream.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Stream]
---

# iOS Host Stream

## Purpose and interface

Private view stream reader of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the reading of the wire format: one little-endian word at a time, and a length-prefixed UTF-8 field. Dispatch of instructions and node lookup stay in the host, because node lookup needs the node table. The reader is the layer below both.

The header provides:
- `pudu_stream_defect(problem, value)`: prints `pudu: a view stream <problem> <value>` and aborts the process.
- `pudu_reader`: the cursor over one stream, holding its bytes, its length and the position of the next word.
- `pudu_word(reader)`: one little-endian 32-bit word.
- `pudu_text(reader)`: a text field, its UTF-8 length word and the bytes that follow.

## Behavior

- A stream is read from its first byte to its end, one word per read. Words are little-endian, the layout [[Std Mobile Stream]] writes.
- `pudu_word` refuses a stream that ends inside an instruction: a read past the end is a defect, and the process ends with a message naming it.
- `pudu_text` reads its length word, then exactly that many UTF-8 bytes. A stream that ends inside the text is a defect, as for a word.
- Text is copied into a string the caller owns, so it stays valid after the stream is released.
- The reader holds no state beyond its cursor. Each instruction handler reads its own words in order.

## Invariants

- Every read advances the cursor by exactly the bytes it consumes, so a handler that reads its words in the order the encoder wrote them stays aligned with the next instruction.
- A defect ends the process; no handler continues on a malformed stream.

## Negative Logic

- No dispatch. The reader never chooses an instruction; [[iOS Host Adapter]] does.
- No node lookup and no node table. Those need the host's state, which the reader does not hold.
- No validation of a word's value. Codes and ids are checked by the handler that uses them.
- No retry of a truncated stream. The defect ends the process.

## Dependencies and consumers

Depends on Foundation for the string type and on the C library for the output of a defect. Included by [[iOS Host Adapter]], which dispatches each instruction through its reader. Its wire format is written by [[Std Mobile Stream]]. The capability handlers of [[iOS Host Gesture]], [[iOS Host Feedback]] and [[iOS Host Access]] read through it.

## Resolved Grill Log

- **Q:** Why move the reader out of the host? **A:** Reading the wire format is a responsibility apart from dispatching it. The move keeps the host under its line budget as the capability handlers are added, and a reader that is tested alone cannot depend on the node table.
- **Q:** Why abort on a defect rather than skip the instruction? **A:** A stream the encoder did not write is a program bug, and skipping part of it would leave the screen in a state no commit produced. The defect message names the problem, so the bug is found at its source.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Stream]] · [[Native iOS Capabilities Delivery]]
