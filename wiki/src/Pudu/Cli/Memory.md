---
type: module
path: "@root/src/Pudu/Cli/Memory.hs"
fidelity: Active
aliases: [CLI Memory Failure]
---
# CLI Memory Failure

## Purpose and interface

Export withMemoryFailure :: IO a -> IO a. Catch only AsyncException HeapOverflow
at the executable boundary, write Host Failure Vocabulary plus newline to stderr,
flush and exit 1. Success returns unchanged. StackOverflow, UserInterrupt,
ThreadKilled and all unrelated exceptions propagate. The evaluator-library API
is unchanged. Bracket cleanup inside the action runs before the outer handler.

## Resolved Grill Log

- **Q:** Catch SomeException? **A:** No; only the exact heap-exhaustion constructor is selected.
- **Q:** Turn cancellation into a memory failure? **A:** No; every other asynchronous exception propagates.
- **Q:** Put presentation in Eval? **A:** No; the CLI owns streams and process status.

## Dependencies and consumers

[[Host Failure Vocabulary]] · [[Pudu CLI]]

## Referenced by

[[src/_MOC]] · [[Native Execution Frames]]
