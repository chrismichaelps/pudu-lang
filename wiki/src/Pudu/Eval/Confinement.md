---
type: module
path: "@root/src/Pudu/Eval/Confinement.hs"
fidelity: Active
tags: [module, runtime, security]
aliases: [Eval Confinement]
---
# Eval Confinement

Cell/mutex disposal and completed-thread forgetting are admitted because they only release resources
owned by the evaluation. Resolved Grill Log: confinement must permit cleanup of admitted creation.

`pudu run --confined` sets a process-wide switch before evaluation. `guardConfined` stops effect dispatch and every foreign call with `E7027` unless `keptWhenConfined` lists the effect: standard streams, a given line, arguments, exit, clocks and time zones, path separators, compression, randomness, stop signals, threads, channels, locks, and cells.

Resolved Grill Log: the kept effects are an allow-list, so an effect added to the runtime is refused in a confined run until it is deliberately listed; nothing a program runs can clear the switch.
