---
type: module
path: "@root/src/Pudu/Eval/Runtime.hs"
fidelity: Active
tags: [module, runtime, lifecycle]
aliases: [Eval Runtime]
---
# Eval Runtime

## Purpose and interface

Own the resource lifetime independently of an individual evaluation result.
withRuntimeEnv :: (Env -> IO a) -> IO (a, [Diagnostic]) allocates isolated stores and brackets
all exits. Concurrent workers and child processes stop before foreign handles, TLS, sockets and
files close. Foreign cleanup diagnostics are drained after close on normal completion.

Resolved Grill Log: the callback may evaluate multiple actions within the same resource lifetime;
its returned values must not be used for host effects after scope exit. No global registries.
Existing one-shot evaluation delegates here, preserving per-run isolation.

## Dependencies and consumers

[[Eval Env]] supplies evaluation state; [[Evaluator]] supplies action/outcome semantics.
Runtime owns resource stores; Context uses Runtime and Evaluator without reverse dependency.

## Grill Log

Resolved: separate resource ownership from the duration of one command, without process-global state.
No builds, tests, reviews or measurements run. No release-readiness claim.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Repl Session]]
