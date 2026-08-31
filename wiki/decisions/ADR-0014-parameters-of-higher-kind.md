---
type: adr
status: accepted
date: 2026-08-31
tags: [adr, types, generics, traits]
aliases: [ADR-0014 Parameters of Higher Kind]
---

# ADR-0014 — Parameters of Higher Kind

## Context

`map` is written five times in the standard library — on `Array`, `Option`, `Result`, `Iter`, and
`Tree` — and the five cannot be related to one another. Neither can `fold`, nor an effectful
traversal, nor anything else whose subject is *which container* a value sits in. A program cannot
write a function over "some container of `T`" at all.

The reason is that a type parameter stands for a type. `trait Mappable[F]` cannot say `F[A] -> F[B]`
because `F` may not be applied, and `E3038` refuses the attempt. Every generic bound is a nominal
trait over a type of kind `*`.

Building `Std.Tree` met this four times in one module: `Functor`, `Applicative`, `Monad`,
`Foldable` and `Traversable` had to be shipped as separately named per-type functions, an effectful
traversal had to name its carrier (`mapResult`, `mapOption`) and be written once per carrier, and a
breadth-first effectful unfold was left out rather than written a third time.

## Decision

Admit type parameters that stand for a type constructor, written with their arity and applied like
any other constructor.

- A parameter declares its arity in its own declaration: `F[_]` takes one argument, `F[_, _]` takes
  two, and a bare `F` takes none as it does today. The arity is written, never inferred from use.
- A parameter of arity *n* may be applied to exactly *n* arguments and to no other number. `E3038`
  continues to report every other case, including a bare parameter given arguments and a
  higher-kinded one given the wrong number.
- A trait may take such a parameter, so `trait Mappable[F[_]]` is admissible and its members may
  write `F[A]` and `F[B]`.
- An implementation names a bare constructor: `impl Mappable[Tree] for Tree`. The constructor is
  never partially applied and never written as a lambda over types.
- Unification solves a constructor variable against a constructor of the same arity, and its
  arguments pairwise. It does not solve a variable applied to a variable, and does not decompose an
  application against a differently-shaped one.

## Consequences

The decidable fragment is what is admitted, and it is admitted by construction rather than by a
solver that gives up. A head is a named constructor or a parameter; it is never a computation over
types. That is what keeps inference terminating and what keeps a failure explainable — a mismatch
names two constructors, not two unsolved applications.

Kinds are arities, not a kind language. There is no `* -> * -> *` to write and no kind polymorphism.
A parameter takes a number of arguments, that number is declared, and applying it wrongly is one
diagnostic. This is deliberately smaller than a full kind system and is expected to stay so until a
feature needs more than arity.

What this does not include, and each for its own reason:

- **No functional dependencies and no associated types.** Both change how an instance is selected,
  and selection is already the subtlest part of the checker.
- **No partial application of a constructor.** `Result[Str]` as a one-argument constructor would
  need a kind language and an ordering convention on a type's own parameters, which is a second
  decision hiding inside this one.
- **No higher-kinded inference.** A parameter's arity is written. Inferring it from use makes two
  uses at different arities a conflict reported far from either.

## Alternatives rejected

- **Inferring arity from use.** Smaller to implement and worse to read: the declaration stops saying
  what the parameter is, and a conflict between two uses is reported at whichever came second.
- **Leaving it out and keeping per-type names.** This is what shipped, and it works — every
  operation exists. What it costs is that they cannot be shared, so each new container repeats them
  and no program can abstract over one. That cost is paid once per container, forever.
- **A full kind system.** More than any current need, and every part of it would have to be
  explained in the grammar before a reader could use the small part they wanted.

## Referenced by

[[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Type Formation]] · [[Type Unify]]
