---
type: architecture
aliases: [Native Output Callable Values]
tags: [backend, callables, output]
---
# Native Output Callable Values

Represent print, printPart, printError and printErrorPart as ordinary owned
callable boxes with their checked fn(Str) -> Result[(), Str] type. Their
behavior remains the evaluator's BuiltinValue behavior, including when stored
beside user functions of exactly the same type. Actual compiled/tree probes
agree on rendering, equality and operator wording in /tmp/pudu-builtin-probes.log.

## Resolved Grill Log

- Resolve local values, constants and module functions before recognizing a
  prelude output name as an intrinsic value. Preserve all existing shadowing.
- Lower Intrinsic owns one generated Core body per output builtin. Parameters
  use the ordinary named-function ABI without an environment. Reuse Lower
  Call's Result construction through a shared outputResult Core factory;
  do not fabricate checked syntax, type facts or another IO implementation.
- CoreClosureInfo gains closureIsBuiltin independently of its environment flag.
  Builtin boxes use stable builtin identity sites and names. Show/display/entry
  write <builtin name>; equality keeps builtin identity separate from functions.
  All callable values remain non-orderable, including inside aggregates.
- Function descriptors gain counted. Source functions and lambdas count;
  intrinsic output bodies do not. The engine checks, increments and decrements
  depth only for counted frames, including when builtin calls happen at the
  maximum allowed source depth. Every frame still participates in ownership,
  result transfer and unwind cleanup. Runtime revision becomes 15.
- Generalize CoreVariantName/FrameVariantName to CoreRuntimeKind/FrameRuntimeKind.
  These read the dynamic kind for sums and callables: current variant name,
  function, or builtin. Operator E7001 and key E7008 must read callable kind at
  runtime, rather than infer it from the static function type. Add callable
  unary refusals as E7001 where the evaluator accepts and executes the source.
- Keep exact argument-before-callee order from existing indirect calls. Output
  Results and failed buffers use the same output runtime as direct calls.
  No helper invokes the interpreter or changes the oracle.

## Ownership and evidence

Backend Engineer owns Core/frame callable metadata, dynamic kind projection,
Lower/{Intrinsic,Call,Body,Scalar,Keyed,Lambda,Layout}, frame lowering/emission,
aggregate helpers, counted frame dispatch and runtime revision. Test Engineer
owns a bounded output-callable corpus, isolated failed-handle extension and
native/cleanup registration. Runtime Aggregate length checks and FrameRuntimeSpec
overflow probes also belong to this slice after the strict GCC finding.
Corresponding complete mirrors precede source
edits. No sub-agents; independent review remains pending.

Success evidence covers all four tags, equality against user functions,
entries, arrays/records/captures/returns/generic calls, shadowing, partial stream
bytes and a source-depth boundary. Failure evidence covers mixed dynamic
operator kinds, key refusals, failed-handle Results and user-function depth
checks beside uncounted builtins. Count allocations and run focused strict
Clang/GCC/ASan+UBSan and both evaluators. Keep the full release gate unchanged;
full-suite/platform/review evidence remains required before promotion. Other
builtin families, bound methods and defaults remain in the full native goal.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native Output Callable Delivery]] · [[Native Output Results]] · [[Native Named Callable Dispatch]]
