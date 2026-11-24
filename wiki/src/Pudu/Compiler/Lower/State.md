---
type: module
path: "@root/src/Pudu/Compiler/Lower/State.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower State]
---

# Compiler Lower State

## Purpose and interface

Own program context, per-function scopes, local numbering and accumulated typed refusals.

Exports: `CoreSignature(..), Head(..), Instance(..), LowerContext(..), LowerState(..), LoopFrame(..), ModuleScope(..), emptyContext, startFunction, refuse, refused, halt, lookupLocal, bindLocal, intType, resolveFunction, lookupConstant, lookupInitializer, inModule, withTypeBindings, isModuleQualifier`.

## Algorithm and invariants

Program context survives function boundaries; local numbering and scopes reset. The optional result records the declared non-entry type or the first explicit entry return, so resultless outer blocks cannot erase an explicit Int return. Refusals preserve source spans and never throw.

The program context carries the entry name, declaration-ordered function
table, signature memo, worklist queue, visited set, accumulated refusals and
completed Core functions. Per-function state carries next local ID, lexical
scope frames, optional result type, numeric loop supply and nearest-first loop
frames holding optional source labels and observed break types. CoreSignature carries the parameter
locals and result type. `startFunction` binds parameters in a fresh frame,
numbers them from zero and starts subsequent locals after them; loop IDs restart
at zero and loop frames empty at each function boundary; context remains
unchanged. Lookup searches inner frames before outer frames. A refusal prepends
one source-spanned native diagnostic; `halt` adds it and returns no subtree,
while `refused` returns no subtree without adding a duplicate diagnostic.

```haskell
emptyContext :: Text -> Text -> Map Text ModuleScope -> [(Text, (Text, Located Function))]
  -> Map Text Instance -> Map (Text, Text) Text -> Map (Text, Text, Text) Text
  -> Map (Text, Text) Head -> LowerContext
startFunction :: LowerState -> [CoreParameter] -> Maybe CoreType -> LowerState
halt :: Span -> Text -> LowerState -> (LowerState, Maybe a)
```

## Negative logic

No host exceptions, semantic rechecking, global mutable state, or backend emission. Unsupported syntax remains a typed E6001 refusal.

## Dependencies and consumers

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Compiler Lower Signature]] · [[Pudu Core]] · [[Native Diagnostic Contracts]]. Only lowering modules consume this phase-owned module.

## Grill Log

- **Q:** How is a written callee resolved? **A:** `resolveFunction`, in the current module, the way the evaluator links imports: the module's own function, a selectively imported name, or `Qualifier.name` through an import without a list, the qualifier being its alias or its path's last segment (#539).

- **Q:** Why extract this responsibility? **A:** State ownership and signature admission are stable boundaries independent of mutually recursive expression/block traversal. Each remains reviewable below 500 lines. _Rejected:_ an oversized body module or a circular expression split.
- **Q:** Can refactoring alter accepted semantics? **A:** No; only explicit corrections preventing invalid Core returns and Result erasure are permitted. Signature refusals and scope resolution retain their source provenance. _Rejected:_ backend inference or approximation.

## Method instances (#551)

Resolved Grill Log: the context carries `contextInstances` (a body under its
own key, with its module, declaration, scheme and bindings) and the
`contextMethods`/`contextTraitMethods` indexes. `inModule` keeps the bindings
of the body being lowered; `withTypeBindings` sets a callee's own.

## Self at the call (#552)

Resolved Grill Log: `instanceSelfAtCall` marks an inherited default of a
generic owner, whose `Self` is the receiver's type and is only known at the
call.

## Declared entry result (#553)

Resolved Grill Log: `lowerDeclaredResult` holds the entry's checked result
for [[Compiler Lower Try]] only; every other function already knows its
result from its signature.

## Closures (#555)

Resolved Grill Log: `lowerCurrentKey` names the body being lowered, and
`contextClosures` records every closure made so far.

## Foreign declarations (#850)

`ModuleScope` records each foreign function a module declares as a `ForeignTarget` (library, version, symbol). `lookupForeign` reaches one by a bare name, the module's own or a selectively imported one, unless a local shadows it.

## Resolved Grill Log for #876 — Native callback lowering

Callback registrations follow module and selective imports and respect local
shadowing. Foreign targets keep their checked function/context pairs.

## Resolved Grill Log for #877 — Native loan lowering

A foreign target retains loan modes at native positions, before contexts and output slots are removed.

## Resolved Grill Log for #877 — Checked foreign bounds

Foreign target bounds refer to native positions, as do callback contexts and output slots.

## Resolved Grill Log for #877 — Returned run ABI

Foreign targets retain the checked length-slot index and opaque identity for a returned allocation.

## Resolved Grill Log for #877 — Native nullable loans

Retain nullable native positions so lowering can map direct call arguments after removing output and context slots.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Lower]] · [[Compiler Lower Body]]

## Scalar loop-control extension (#489)

[[Compiler Lower Control]] owns nearest labelled target resolution, break-type joins,
while/loop values and direct terminal Never detection. State resets loop numbering
and frames per function. Body delegates through traversal callbacks; if branches
join Never with reachable types. Print-valued break operands refuse Result erasure.

Resolved Grill Log: while conditions lower before their frame; operands lower
before break observation; labels become numeric identities; only scalar/unit
results are admitted. Rejected silent Result erasure and source-label C names.


## Solved native type inputs (#491)

LowerContext retains contextTypes :: LowerTypes. emptyContext :: Text -> LowerTypes -> [(Text, Located Function)] -> LowerContext. Facts survive every function boundary without rechecking or global state.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.

## Folded constant names (#543)

Resolved Grill Log: ModuleScope adds scopeConstants :: Map Text (Maybe Frozen),
containing only declarations that module owns. lookupConstant resolves a local
shadow first, then an owned, selected or qualified constant through the same
module maps as calls, returning Nothing for a nonconstant and Just Nothing for
a declared constant with no supplied portable fold. Imports never re-export
another module's constant. [[Compiler Lower Constant]] owns projection.

## Mutable loans (#651)

CoreSignature carries `signatureLoaned`, the positions of its `&mut`
parameters, and LowerState carries `lowerLoaned`, the loaned locals of the
function being lowered; `startFunction` clears it, so a lambda's `return`
answers only its own value. See [[Compiler Lower Loan]].

## Derived trait arguments (#824)

`Instance.instanceDerived` holds the default body's rigid names mapped to
unformed `Type`s in the implementation scheme's namespace. `specialize` first
settles implementation parameters, then forms the derived types and installs
them as the body's bindings.

Resolved Grill Log (#824): `instanceDerived` maps the default body's rigid names
to types in the implementation scheme's namespace. It also carries renamed own
method parameters and concrete trait arguments, so no same-spelling binding
overrides an implementation parameter before specialization.

## Host scopes, type arguments and initializers (#846)

Resolved Grill Log: `lowerOpenScopes` records each open `async with scope` by
the loops around it, so a transfer joins exactly the scopes it crosses;
`lowerTypeArguments` carries the written type arguments of the call whose
callee is being admitted. `ModuleScope` also keeps `scopeInitializers`, so
[[Compiler Lower Constant]] can compile a constant folding left no product in
its declaring module; `lookupInitializer` names that module and expression.
`emptyContext` receives implementation `heads` for settling bound-only
parameters.

## Foreign handles (#853)

ForeignTarget carries ownership mode and release-call status alongside library and symbol metadata.

## Scalar output slots (#854)

Resolved Grill Log: Retain the written output positions in the foreign target.

## Owned output slots (#854)

Resolved Grill Log: Retain each slot destructor beside its checked ABI position.

## Qualified foreign targets (#873)

`lookupQualifiedForeign` answers the foreign target a `Qualifier.name`
reaches through the current module's qualifiers, unless a local shadows
the qualifier. Resolved Grill Log: reuse `scopeQualifiers`, as
`resolveFunction` does for qualified functions.

## Resolved Grill Log for retained split callbacks

Carry callback capability for every call declared in a block that splits
registration from its trampoline. A later call without token parameters may
invoke a retained callback, so it needs the same outbound failure scope and
must allow the handler to acquire the gate.

## Resolved Grill Log for native callback groups

Resolve callback group constructors through ordinary native name visibility and shadowing.

## Resolved Grill Log for Objective-C dispatch

Preserve the resolved Objective-C method on a foreign target.

## Resolved Grill Log for Objective-C delegates

`scopeDelegates` records the delegate declarations visible in the current scope so that `lookupDelegate` can answer them during lowering.

## Loop expectation and observation (#956)

Resolved Grill Log: the optional checked carrier guides value projection
at a break. The observed break type continues to record which result can
leave the loop. The two fields remain separate for divergent operands and
for synthetic loops without a checked carrier.

Resolved Grill Log. Each frame tracks the set of observed emitted
break carriers. [[Compiler Lower Control]] combines mixed exits
before emitting the loop's destination slot. Observations stay local
to the frame and exclude diverging operands.

## Sanctioned runtime results for internal calls (#956)

Resolved Grill Log. Retained constructor templates preserve the
canonical owner, label and checked result for later specialization.

Resolved Grill Log: keep the current pass's observations separate from
the prior pass's settled carriers. A body can publish explicit result
carriers while a replay is pending. Entry, lifted bodies and external
signatures retain their established ABI.

## Stored callable dispatch (#956)

Resolved Grill Log: The worklist retains the source and capture types for synchronous callable bodies. Call sites can request a copy without re-evaluating the source closure.

## Runtime layouts in stored methods and builtins (#956)

Resolved Grill Log: Method and intrinsic templates retain their checked signature and the information to regenerate a body. A method also retains its lexical facts and capture layout.

## Native task result layouts (#956)

Resolved Grill Log: The worklist records task failure carriers by their declared failure type and replays scopes when a carrier becomes reachable.

## Mutable slot layout discovery (#956)

Resolved Grill Log: Identify a mutable declaration by its body key and source span. Temporary slot numbers may change when lowering replays.

## Stored mutable parameter layouts (#956)

Resolved Grill Log: A mutable parameter is identified by the native body key and its parameter position. A generated wrapper can share this identity across member reads.
