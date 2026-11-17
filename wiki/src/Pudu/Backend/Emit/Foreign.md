---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Foreign.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Foreign]
---
# Backend Emit Foreign

One wrapper per foreign declaration a program calls (#850). The wrapper takes
the call's E7015 site and the frame cells, converts each cell to the C type the
interpreter's bridge crosses it as, calls through a function pointer of that
exact type resolved once by [[Native Host Foreign]], and converts the answer
back to its cell.

## Interface

- `foreignCall` — the call text at a site, registering a site with E7015 and
  the interpreter's help, and the parts it needs.
- `foreignsOf` — every declaration a module's frames call, each once.
- `foreignWrappers` — their definitions.

## Resolved Grill Log

- **Q:** Where does per-declaration C live? **A:** In the module, after the
  aggregate helpers, from the declarations the frames carry. A call site only
  names its wrapper.
- **Q:** Cast `dlsym`'s object pointer to the function's type? **A:** No; the
  loader answers `void (*)(void)` and the wrapper converts between function
  pointer types, which ISO C allows.

## Text and bytes (#851)

A wrapper taking text receives an E7017 site and validates each `Str` before resolving the function and copies it with a closing nought before dispatch, releasing the copies after the call. A wrapper answering text receives E7024 and E7025 sites, built with the interpreter's words for the declaration's symbol, and copies the answer out before releasing the argument copies, since it may point into one. `Bytes` cross as the lent address of their storage.

## Records (#852)

Record parameters are packed into their structs (with [[Backend Emit Foreign ABI]]) before dispatch, their text fields held for release after the call; a record result is unpacked into a new box before the argument copies are released. `foreignNeeds` gathers, per module, each leaf's conversion and the constructor and release of every record crossed, since both its pack and unpack functions are written.

## Handle crossings (#853)

Validate text, resolve the invoked symbol and any result destructor, then
check handle liveness before entering foreign code. Wrapper identities retain
full checked crossing types and ownership policy. A cached typed destructor
can release a claim during teardown without resolving another symbol. Validate
raw result text before allocating copies, and free argument scratch before
reporting missing or invalid returned text. Select text helper dependencies by
crossing direction. Record codecs still emit both directions.

An optional handle parameter (#935) is passed through `pudu_foreign_optional_handle`, which the
wrapper calls before dispatch so that `None` crosses as a null pointer and `Some` as the checked live
address.
## Resolved Grill Log for #877 — ABI loan storage

[[Backend Emit Foreign Loan]] packs each scalar or record loan into a C local of its
exact ABI type. The native function receives the address of that local.
A shared parameter uses a const-qualified pointer. A mutable parameter's
final value joins the result tuple used by ordinary native place writeback.

## Resolved Grill Log for #877 — Post-call settlement

Arm post-call capture inside the crossing and keep mutable ABI locals outside its jump boundary. Release all callback leases on either conversion exit. Only then return the loan finals.

## Resolved Grill Log for #877 — Checked foreign bounds

Pass one extent diagnostic site to each wrapper with length relations. Check each target in declared order before calling C.

## Resolved Grill Log for #877 — C11 array crossings

Use the sized array wrapper before the raw crossing. Arm the storage cleanup around preflight and after native return, and disarm it while the library or a callback is running.

## Resolved Grill Log for #877 — Optional handles

Check liveness only for a present optional handle. Convert null results to None and route present handles through the appropriate owned, counted or borrowed path.

## Resolved Grill Log for #877 — Handle leases during dispatch

Pin present input handles before dispatch can yield, then unpin them after the native shim retakes the gate. If a callback failure discards an otherwise valid result, release the produced claims before reporting the failure.

## Resolved Grill Log for #877 — Returned run copying

Represent a returned run as a native void pointer claimed before checking the length slot. Copy to a Pudu array at the ABI stride and discharge the temporary generation immediately after copying.

## Resolved Grill Log for #877 — Native nullable loans

Select run allocation and guarded dispatch only when the call can allocate scratch. Keep extent checks for nullable arrays with related lengths.

## Resolved Grill Log for Objective-C blocks

A callback parameter written `work: block Work` crosses as one pointer to a block literal, with passing mode BlockPassing and placement BlockCallback. The block is a stack block (isa `_NSConcreteStackBlock`, no copy or dispose helpers) whose last field is the registration key, and it lives for the foreign call only. A callee that keeps the block copies it with `Block_copy`; the copy carries the key, which is how escaping blocks are copied. The block's invoke receives the block first, so the callback must declare its context first; the checker refuses otherwise with E3063 ("callback X must take its context first to cross as a block"). A late invocation after unregister finds the key retired and answers the fallback.
Generated C: the runtime part `host_foreign_block` refuses non-Apple targets with `#error`. Each signature gets a `pudu_block_invoke_<key>` that forwards to the trampoline, and the call site passes a compound-literal block.

## Referenced by

[[Backend Frame Program]] · [[Native Foreign Call Sites]]

## Scalar output slots (#854)

Resolved Grill Log: Initialize scalar slots to zero, pass their addresses, and construct the checked result tuple after dispatch.

## Record output slots (#854)

Resolved Grill Log: use the same record decoder as a by-value result, then release its temporary after the result tuple retains it.

## Text slots (#854)

Resolved Grill Log: A null text slot becomes None. Validate all returned text before allocating result boxes, then copy a non-null text slot into Some.

## Owned output slots (#854)

Resolved Grill Log: Resolve all slot destructors before dispatch. Claim returned handles as one batch before converting the tuple.

## Mixed crossings (#854)

Resolved Grill Log: validate arguments and handles before dispatch. Copy all returned text before releasing any argument scratch that it can alias.

A direct owned handle result participates in the same batch as owned slots.
Reserve space and resolve every destructor before dispatch.

## Conversion needs shared with exports (#899)

`parameterNeeds` and `resultNeeds` are exported for [[Backend Emit Export]],
which converts in the opposite direction: an export's arguments use the
result conversions and its result uses the parameter conversions.

### Split callback placement Grill Log resolved

The wrapper emits typed trampoline addresses and leases only registrations supplied by Pudu.

## Resolved Grill Log for retained split callbacks

Carry callback capability for every call declared in a block that splits
registration from its trampoline. A later call without token parameters may
invoke a retained callback, so it needs the same outbound failure scope and
must allow the handler to acquire the gate.

## Resolved Grill Log for atomic foreign symbol caches

Generated release functions load the published native function through the
loader cache accessor. The cache retains its owning module for the process.

## Resolved Grill Log for Objective-C dispatch

Insert the native receiver and selector at ABI positions, and cast the chosen entry point to a fixed signature.

## Resolved Grill Log for Objective-C ownership

Validate aliases and receiver readiness while the run gate is held. Consume the receiver after preparing scratch and before entering the send.
