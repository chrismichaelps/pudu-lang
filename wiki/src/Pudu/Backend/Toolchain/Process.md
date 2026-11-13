---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/Process.hs"
fidelity: Active
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain]
aliases: [Backend Toolchain Process]
---

# Backend Toolchain Process

## Purpose and interface

The bounded runner every native tool invocation shares, and the failure
vocabulary of the whole toolchain.

```haskell
data ToolchainFailure
  = ToolchainNotFound !Text
  | ToolchainInvocation !Text
  | ToolchainTimedOut !Int
  | ToolchainRejected !Text
  | ToolchainPublishFailed !Text

runTool :: FilePath -> [String] -> Int -> IO (Either ToolchainFailure Text)
timeoutSeconds :: IO Int
tryIO :: IO a -> IO (Either IOException a)
problemText :: IOException -> Text
cleanup :: [FilePath] -> IO ()
```

## Algorithm and invariants

The runner is the one [[Backend Toolchain]] described: a structural argument
list, no shell, its own process group, both pipes drained concurrently into one
64 KiB budget, process exit and both drains inside one deadline, the group
killed on POSIX when it expires, and bounded cleanup. Exit zero answers the
captured output; nonzero is `ToolchainRejected` with it. `timeoutSeconds`
reads `PUDU_CC_TIMEOUT` and defaults to 120.

## Negative Logic (Prohibited Paths)

- No unbounded capture, wait or cleanup.
- No retry and no interpretation of a tool's output beyond its exit status.

## Dependencies and consumers

`process`, `unix` on POSIX, `bytestring`, `text`. Consumed by
[[Backend Toolchain]].

## Resolved Grill Log

Separate process execution from host compiler flags and artifact publication
so future native tools share cancellation and bounded capture.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Toolchain]]
