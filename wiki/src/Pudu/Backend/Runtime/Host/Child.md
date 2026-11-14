---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Child.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Child Programs]
---
# Native Host Child Programs

Export the family's runtime parts and their prerequisites.

Programs started and still running behind their tokens: starting with three pipes, a stated environment and a working directory, reading what a program wrote and what it reported, writing to and closing its input, waiting with and without a bound, stopping; and a program run to its end with its status and both streams collected, as `Pudu.Eval.Child` and `Pudu.Eval.Clock` answer them.

## Resolved Grill Log

- Fork and replace, or ask the system to spawn? Spawn with a path search, the call the interpreter's runtime makes, so what the system accepts and refuses is the same on each machine.
- A working directory that does not exist? The spawn refuses; the refusal names the program, as the interpreter's does.
- Which variables does the program see? Those given, first, then the inherited ones no given name replaces; without inheritance only those given; with inheritance and nothing given, the run's own.
- Do the parent's pipe ends reach other started programs? No: every end closes in a program that is replaced.
- Is a write sent at once? No: bytes wait until 8192 are held or the input is closed, as the interpreter's buffered handle holds them, so a write to a program that has gone answers done until the held bytes are sent.
- A write after the input is closed? Refused, naming the descriptor the input had.
- Closing the input twice? Done already.
- A read of fewer than one byte? Refused after the token is found.
- A status after a signal? The signal's number, negated.
- Waiting twice? The status is kept and answered again; stopping a program that has ended answers its status.
- A bounded wait? Asked every ten milliseconds, giving up the run gate between asks; a negative bound asks once.
- Programs still running when the run ends? Their pipes are closed and each is asked to stop, without waiting.
- A token never issued? Refused in the interpreter's words; a token stays for the whole run.
- Output that is not UTF-8 from a program run to its end? Refused at the first byte that is not.
- A peer that closed its input while this side writes? The write answers the failure; no signal ends the run.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
