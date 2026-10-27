---
type: module
path: "@root/src/Pudu/Compiler/Lower/Try.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Try]
---
# Compiler Lower Try

## Purpose and interface

`lowerTry` lowers `value?` to a two-arm `CoreMatch` over the operand: the
success variant (`Ok` or `Some`) binds its payload, which is the expression's
value, and the failure arm returns from the enclosing function. This is the
evaluator's `unwrapTry`.

## Resolved Grill Log

- **Q:** Return the failure value itself? **A:** It is rebuilt: `Err(e)` from
  a `Result[Int, E]` returned out of a `Result[Str, E]` function is the same
  value, but a different native layout. Its payload is read from the bound
  local, so it runs no code twice.
- **Q:** What is the enclosing result in `main`? **A:** The entry's checked
  result, kept in `lowerDeclaredResult` for `?` alone. Feeding it into the
  entry's own result handling made a body ending in `print(...)` lower as a
  Result-returning `main`; that path keeps starting from nothing.
- A Never operand passes its transfer through; `?` of print's Result refuses.
  Mismatched failure types cannot reach here (checking rejects them) and refuse
  if they do.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Control]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]]
