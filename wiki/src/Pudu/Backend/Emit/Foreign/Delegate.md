---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Foreign/Delegate.hs"
fidelity: Active
grammar: Haskell
aliases: [Backend Emit Foreign Delegate]
---

# Backend Emit Foreign Delegate

Emit the C11 definitions for Objective-C delegate classes declared inside a
foreign block. Collect each delegate construction from the module's frames,
then write one method closure per member signature and one constructor per
delegate class.

## Interface

- `delegatesOf` collects the `CoreDelegateNew` operations of a module's frames,
  each delegate class once.
- `delegateDefinitions` emits one `pudu_delegate_method_<key>` per member
  signature and one `pudu_delegate_new_<class>(uintptr_t key)` constructor per
  delegate class.

## Resolved Grill Log

The constructor leases the group registration for its key, defines the runtime
class on first use, creates the instance, and claims that instance through
`pudu_foreign_handle_result`. The claim makes the instance an owned handle, so
its release message runs at teardown like any other owned foreign value.

Method type encodings are derived from the core types of the member signature,
not from the selector text. The selector is checked to have one colon-terminated
segment per argument, so the encoding and the selector agree by construction.

## Referenced by

[[Backend Emit Foreign]] · [[Backend Emit Foreign Callback]] · [[Pudu FFI Objective-C Bridge]] · [[Backend Frame Program]]
