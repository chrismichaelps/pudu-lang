---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/Signal.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Eval Stop Requests]
---

# Eval Stop Requests

`watchForStop :: IO Bool` installs process-wide handlers on supported targets.
`stopRequested :: IO Bool` reads the flag they set. Installing again after
success returns success. An unsupported target returns false without installing
handlers, and its stop flag stays false.

## Resolved Grill Log

- Why a process-wide flag? A stop request targets the process. Each evaluation
  can observe it at a boundary it chooses.
- What belongs in the platform-specific build? The handlers and the flag writes
  they use. The read-only fallback builds without either.

## Referenced by

[[Pudu/Eval/_MOC]] · [[Pudu Desktop Delivery]]
