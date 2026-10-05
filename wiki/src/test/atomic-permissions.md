---
type: module
path: "@root/test/atomic-permissions.py"
fidelity: Active
tags: [module, test, filesystem]
aliases: [Atomic Permission Gate]
---
# Atomic Permission Gate

## Purpose and interface

`python3 test/atomic-permissions.py PATH_TO_PUDU` checks [[Std Fs]] against actual
POSIX permissions. Each compiler subprocess sets its own umask with a shell wrapper;
the test runner never changes the process-wide mask. It checks both byte and text
writes under 022 and 077, comparing new files with [[Std Io]] creation and preserving
0640, 0600, and executable 0755 destinations. It also checks private 0600 scratch,
symlink replacement without target mutation, missing-parent refusal, rename refusal
over a populated directory, retained contents and absence of stage/template leaks.
Other platforms explicitly skip POSIX mode assertions. [[Repository Gates]] runs this
script against the freshly built optimized executable.

## Grill Log

- **Q:** Change umask in a shared test process? **A:** No; start each Pudu invocation
  through a shell with a child-local mask. _Rejected:_ racing global mask mutations.
- **Q:** Check only portable permission booleans? **A:** No; stat actual POSIX modes
  externally so lost group/other or executable bits are observable.

Resolved Grill Log: exercise public byte/text APIs in isolated processes and inspect
exact contents, modes, output, refusal and cleanup outside the language.

## Referenced by

[[Std Fs]] · [[Eval Io]] · [[Repository Gates]]
