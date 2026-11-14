---
type: module
path: "@root/test/Pudu/Backend/RenderingCallablePrograms.hs"
fidelity: Active
aliases: [Backend Rendering Callable Programs]
---
# Backend Rendering Callable Programs

Export renderingCallableSuccessPrograms (explicit stdout/stderr) and
renderingCallableRefusalPrograms (runtime failures). Cover simultaneously
specialized display/show, identity, primitive/aggregate/callable arguments,
generic calls, records, captures, returned builtin values, source/local
shadowing, entry values, exact depth and owned text reuse. Failure cases cover
operator/key kinds, a source function at the same depth and argument failure.

## Resolved Grill Log

Explicit outputs supplement both evaluator oracles. Every healthy program
also runs under counted allocation wrappers through the shared callable
corpus. Derive depth probes from callDepthLimit. Failures must compare exact
source diagnostics and ordered output rather than accept a native refusal.
Do not infer full builtin coverage from rendering support.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Rendering Callables]] · [[src/Pudu/Backend/_MOC]]

Export renderingCallableModulePrograms for two provider-owned Token records
with different field types. Resolved Grill Log: complete canonical callable
types must keep these same-spelling specializations separate across modules.
The existing module corpus executes this case in the full gate; focused CLI
checks compare both evaluators and native Clang/GCC/sanitizer builds.
