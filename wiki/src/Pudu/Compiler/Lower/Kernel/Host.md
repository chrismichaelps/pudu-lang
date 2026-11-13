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
| Standard input | `readLine`, as `Result[Option[Str], Str]` |
| Process | `clock`, `clockNanos`, `now`, `zoneOffset`, `sleepMillis`, `arguments`, `environment`, `temporaryPath`, `userHome`, `pathSeparators`, `searchSeparator`, `exit`, `secureRandomBytes`, `formatTime`, `parseTime`, `signalWatchStop`, `signalStopRequested` |
| Concurrency | `cellDispose`, the mutex builtins, `channelOpen`, `channelWaiting`, `channelFinish`, `joinThread`, `forgetThread` |
| Files | reading, writing and appending files, existence, removal, directories, renaming, sizes, permissions, symbolic links, canonical paths, listings, temporary files, atomic writes, and the open-handle builtins |
| Sockets | `tcpListen`, `tcpAccept`, `tcpConnect`, `tcpConnectWithin`, `socketSend`, `socketSendWithin`, `socketReceive`, `socketReceiveWithin`, `socketClose`, `socketFinish`, `socketPeer`, `socketPort` |
| TLS | `tlsConnect`, `tlsConnectWithin`, `tlsUpgradeWithin`, `tlsSend`, `tlsSendWithin`, `tlsReceive`, `tlsReceiveWithin`, `tlsClose`, `tlsCloseWithin`, `tlsPeer` |
| Compression | `gzipCompress`, `gzipDecompress`, `deflateRaw`, `inflateRaw` |
| Child programs | `spawnProgram`, `spawnProgramWith`, `childReadChunk`, `childReadErrorChunk`, `childWriteChunk`, `childCloseInput`, `childWait`, `childWaitWithin`, `childStop`, `runProgram` |

## Resolved Grill Log

A bounded variant is its own row with its own runtime function, because its
budget is an operand and the unbounded form has none. A host call that can fail answers through the host state rather than a
second result, so one description serves every such builtin. Each table row
is the builtin's own checked signature; nothing is inferred.

## Referenced by

[[Compiler Lower Kernel]] · [[Native Host Services]]

## Native desktop (#856)

Resolved Grill Log: Lower the monomorphic desktop builtins through the host outcome carrier to [[Native Host Desktop]].
