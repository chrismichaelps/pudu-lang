---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Input.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Input]
---

# Native Host Input

Exports the standard-input line part and the byte-sequence bounds and
decoding diagnostics shared with [[Native Host Files]].

## Resolved Grill Log

- Return one line with its terminal newline removed, including empty lines
  and an unterminated final line. End of input returns absence.
- Release the run gate before locking or reading the stream. Keep the lock
  through byte validation. An interrupted read retries, and a temporarily
  unavailable descriptor waits for readiness. Release the stream lock
  before reentering the run gate.
- Report the leading byte of the first malformed sequence as soon as it
  fails. Keep that refusal for later reads. The decoder accepts a bounded
  sequence at a time and only publishes validated owned text.

## Referenced by

[[Backend Module Map]] · [[Native Host Runtime]] · [[Native Host Files]] · [[Native Host Services]]
