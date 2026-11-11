---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Kernel/Host.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Kernel Host]
---
# Compiler Lower Kernel Host

Export hostPrimitives: the host builtins whose signatures hold no type
parameter, each described by its operands, guards and answer as
[[Compiler Lower Kernel Shape]] defines them.

| Family | Builtins |
| --- | --- |
| Math | the binary64 kernels, from the one list [[Native Host Math]] emits |
| Process | `clock`, `clockNanos`, `now`, `zoneOffset`, `sleepMillis`, `arguments`, `environment`, `temporaryPath`, `userHome`, `pathSeparators`, `searchSeparator`, `exit`, `secureRandomBytes` |
| Concurrency | `cellDispose`, the mutex builtins, `channelOpen`, `channelWaiting`, `channelFinish`, `joinThread`, `forgetThread` |
| Files | reading, writing and appending files, existence, removal, directories, renaming, sizes, permissions, symbolic links, canonical paths, listings, temporary files, atomic writes, and the open-handle builtins |

## Resolved Grill Log

A host call that can fail answers through the host state rather than a
second result, so one description serves every such builtin. Each table row
is the builtin's own checked signature; nothing is inferred.

## Referenced by

[[Compiler Lower Kernel]] · [[Native Host Services]]
