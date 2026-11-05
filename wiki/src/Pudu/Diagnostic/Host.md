---
type: module
path: "@root/src/Pudu/Diagnostic/Host.hs"
fidelity: Active
aliases: [Host Failure Vocabulary]
---
# Host Failure Vocabulary

## Purpose and interface

Export memoryFailureMessage :: String, the ASCII host-failure headline shared
by the CLI and emitted executables: pudu: memory allocation failed. It has no
Pudu diagnostic code, source span, recoverable value, terminal color or help.
The process boundary writes one newline to stderr and exits 1.

## Resolved Grill Log

- **Q:** Invent a source diagnostic for host exhaustion? **A:** No; it remains a host failure.
- **Q:** Preserve engine-specific RTS text? **A:** No; use one explicit executable boundary, without changing evaluator-library exception behavior.
- **Q:** Promise recovery from OS termination? **A:** No; this contract covers reported allocation failure and catchable HeapOverflow only.

## Dependencies and consumers

[[CLI Memory Failure]] · [[Backend Runtime]] · [[Native Execution Frames]]

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]
