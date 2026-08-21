---
type: domain
tags: [domain]
aliases: [Ownership Model, Borrowing]
---

# Ownership

- **Definition:** Static authority determining who may move, read, mutate, or destroy a non-copy value.
- **Move:** Assigning or passing an owned non-copy value transfers authority; later use is rejected.
- **Shared borrow:** `&T` permits reads, may coexist with shared borrows, and blocks mutation/move while live.
- **Exclusive borrow:** `&mut T` permits mutation and excludes every other live access.
- **Lifetime:** v1 infers lexical/non-lexical regions within a function; references cannot escape their referent or cross task boundaries without `Send`-like trait proof.
- **Copy:** `Copy` is compiler-controlled. Scalar primitives and shared references copy; an aggregate is `Copy` only when every stored field is `Copy` and the type has no `Drop` implementation or resource identity. Mutable references and resource-owning values never copy. User-written `impl Copy` is rejected; generic aggregates are `Copy` only under inferred `Copy` bounds for every copied type parameter.
- **Not:** Reference counting, garbage collection, or runtime borrow checks.

## Referenced by

[[Pudu Type]] · [[Semantics]] · [[Core IR]] · [[ADR-0003-ownership-and-resource-safety]]
