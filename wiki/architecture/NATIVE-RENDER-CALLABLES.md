---
type: architecture
aliases: [Native Rendering Callables]
---
# Native Rendering Callables

Recognize prelude display/show values after nearer locals, constants and
module functions. Consume their exact solved CoreFunctionType with one
represented argument and Str result. Register an intrinsic body using
CoreDisplay/CoreShow of a parameter, retaining ordinary lifetime handling.
No duplicate renderer, evaluator call or type inference is allowed.

Key generated rendering bodies by the complete canonical CoreType, including
nominal owners and nested members, not the printed source type name. Keep
closureSite as builtin plus the tag; observable builtin equality/rendering
must not depend on type instantiation, source location or caller. Intrinsics
have no hidden environment and do not count toward source call depth.
Restore caller-local state while retaining registered context products.
Existing output builtins keep their current keys and shared Result factory.

## Resolved Grill Log

- Same tag at two argument types needs separate bodies, one builtin identity.
- Use canonical structural type identity, not display names that can collide.
- Reuse Core rendering to preserve escapes, floats, held variants and callables.
- Arguments finish before invocation, including transfer/failure; no extra depth.
- Count owned parameters/results through normal frame cleanup, including Str
  display returning its operand and rendering captures/aggregates.
- Missing/unrepresented facts refuse explicitly; no invented callable ABI.

## Evidence and remaining scope

Compare explicit stdout/stderr/status with both isolated evaluators; exercise
aliases, generics, captures, returns, entries, shadowing, simultaneous types,
operator/key failures, argument failure and the exact depth boundary. Run
counted allocation checks, strict Clang/GCC and ASan/UBSan. Full regression and
independent code/architect/wiki review precede promotion. This does not complete
other builtin/method values, default parameters or the full coverage ledger.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Intrinsic]] · [[Backend Rendering Callable Programs]]
