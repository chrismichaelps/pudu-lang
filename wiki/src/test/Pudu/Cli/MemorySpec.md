---
type: module
path: "@root/test/Pudu/Cli/MemorySpec.hs"
fidelity: Active
aliases: [CLI Memory Tests]
---
# CLI Memory Tests

## Purpose and interface

Export memoryProperties. Capture stderr around controlled actions and verify
normal results, HeapOverflow message/status and propagation of StackOverflow,
ThreadKilled and UserInterrupt. The shared text is also asserted literally,
so two equally wrong renderers cannot pass. Tests inject the exact exception;
real limited-heap CLI execution is separate evidence.

## Resolved Grill Log

- **Q:** Catch cancellation to simplify assertions? **A:** No; prove each constructor propagates.
- **Q:** Leave stderr redirected? **A:** Restore/close handles with bracket/finally.

## Dependencies and consumers

[[CLI Memory Failure]] · [[Host Failure Vocabulary]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]
