---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Foreign/Callback.hs"
fidelity: Active
grammar: Haskell
aliases: [Backend Emit Foreign Callback]
---

# Backend Emit Foreign Callback

Emit typed C11 trampolines and rebuild native argument lists from checked
foreign call shapes. Discover callback signatures and unregister results
from the module's frame operations before emitting their helpers.

## Interface

- `nativeArguments` maps ABI positions to arguments, slots, contexts, and
  static trampoline projections.
- `callbackSignaturesOf` and `callbackUnregisterResults` discover required helpers.
- `callbackOperation`, `callbackTrampolines`, and `callbackNeeds` supply
  the generated operations, helpers, and runtime dependencies.

## Resolved Grill Log

A trampoline address is fixed by its typed callback owner. A registration
context comes from the call's token. The trampoline uses that context to
look up the generation before entering Pudu. Reconstruct paired hidden
contexts and split projections without consuming source arguments.

## Resolved Grill Log for Objective-C blocks

A callback parameter written `work: block Work` crosses as one pointer to a block literal, with passing mode BlockPassing and placement BlockCallback. The block is a stack block (isa `_NSConcreteStackBlock`, no copy or dispose helpers) whose last field is the registration key, and it lives for the foreign call only. A callee that keeps the block copies it with `Block_copy`; the copy carries the key, which is how escaping blocks are copied. The block's invoke receives the block first, so the callback must declare its context first; the checker refuses otherwise with E3063 ("callback X must take its context first to cross as a block"). A late invocation after unregister finds the key retired and answers the fallback.
Generated C: the runtime part `host_foreign_block` refuses non-Apple targets with `#error`. Each signature gets a `pudu_block_invoke_<key>` that forwards to the trampoline, and the call site passes a compound-literal block.

## Referenced by

[[Backend Emit Foreign]] · [[Backend Module Map]]

### Split callback placement Grill Log resolved

Native parameter reconstruction preserves split context and trampoline positions.

## Resolved Grill Log for callback byte runs

Validate before allocating cells and copy the run under the callback gate.

## Resolved Grill Log for callback group slots

Mangle member trampolines separately and give all of them the same registration identity.

## Resolved Grill Log for native callback groups

Emit one group registration that retains the record and copies its slot indexes. Each trampoline supplies its member ordinal.
