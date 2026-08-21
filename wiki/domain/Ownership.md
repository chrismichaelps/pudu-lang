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
- **Copy:** Small scalar primitives copy; aggregates move unless they implement the explicit `Copy` trait.
- **Not:** Reference counting, garbage collection, or runtime borrow checks.

## Referenced by

[[Pudu Type]] · [[Ownership Checking]] · [[Core IR]] · [[ADR-0003-ownership-and-resource-safety]]
