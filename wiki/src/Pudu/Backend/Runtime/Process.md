---
type: module
path: "@root/src/Pudu/Backend/Runtime/Process.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Process Context]
---
# Native Process Context

Export processIoLines, the process_io catalogue part. Retain the existing
SIGPIPE handler and pudu_prepare_io interface. Before user code, project
missing standard descriptors into the locked runtime's queue/control-pipe
endpoint types as resolved in Native Output Results. Descriptors and their
flags belong to the process and the OS closes them on process exit.

## Resolved Grill Log

- Check inherited descriptors with fcntl; only EBADF means missing. Preserve
  every valid inherited endpoint, including read-only output descriptors.
- Backend allocation precedes control-pipe allocation. Do not translate
  output errno or install a guessed error string.
- Preparation is one-time even when the fatal diagnostic path restores the
  ordinary SIGPIPE handler. Later source descriptor changes stay visible.
- Guard KQueue/EPoll adapters by platform; no external library, compiler
  inference or Haskell runtime dependency enters generated programs.
- Bootstrap exhaustion and other target adapters remain evidence obligations;
  this module does not claim concurrency coverage.

## Referenced by

[[Native Runtime]] · [[Native Output Results]] · [[src/Pudu/Backend/_MOC]]

## Fatal output readiness (#566)

Resolved Grill Log: Expose pudu_wait_writable(descriptor) within the process_io part. Both ordinary writes and fatal stderr reporting use the locked blocking-FD readiness policy. Initial poll errors still reach the actual write; interrupted blocking waits retry.
