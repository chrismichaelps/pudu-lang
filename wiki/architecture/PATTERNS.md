---
type: architecture
tags: [architecture, patterns, design]
aliases: [Design Patterns, architecture/PATTERNS]
---

# Design patterns in Pudu

Every pattern below was written in Pudu and run. This page records what happened, because "can the
language express X" is a question worth answering with a program rather than an opinion.

The short answer: **most patterns disappear, a few are ordinary code, and one feature was missing
until `dynamic` arrived.**

## Dissolved

These have no expression in Pudu because the language already does what the pattern was working
around. A pattern is a workaround with a name; when the workaround is unnecessary the name has
nothing to attach to.

| Pattern | What replaces it |
|---|---|
| Strategy | a function value |
| Command | a closure |
| Visitor | `match`, with exhaustiveness checked |
| Iterator | the `Sequence` trait and `for` |
| Template Method | a trait's default method |
| Singleton | a module `const` |
| Interpreter | a sum type and recursion |
| Prototype | immutability — binding a value *is* the copy |
| Memento | immutability — a snapshot is the value you already hold |
| Facade, Mediator | a module |

`Prototype` and `Memento` are the clearest case. Both exist to answer "how do I keep an unchanged
copy while something else changes", and in a language where nothing changes in place the question
does not arise. No `Clone` trait is needed and none exists.

## Static

These work through generics with trait bounds. Every dispatch is resolved at compile time and costs
nothing at run time.

| Pattern | How |
|---|---|
| Decorator | a generic type bounded by the trait it decorates |
| Proxy, Adapter, Bridge | the same shape |
| Builder | records and functions returning the type |
| State | a sum type |
| Chain of Responsibility | an array of closures, when the handlers share a type |
| Flyweight | `Map` as a cache |

`Std.Iter`'s adapters *are* the Decorator pattern. `filter(map(source, f), p)` is three decorators
stacked, and the composition is resolved statically with no vtable and no allocation per layer.

## The one that needed a feature

Every pattern that failed, failed the same way:

```pudu
let listeners = [Logger{...}, Counter{...}]
//              ^^^ E3001: expected Logger, found Counter

fn make(kind: Str) -> Shape { ... }
//                    ^^^^^ E3030: Shape is a trait, so it cannot be written as a type
```

Observer over listeners of different types, Abstract Factory, Factory Method, a Composite with
mixed children, a plugin registry — one missing feature explained all of them. There was no way to
say *a value that implements this trait, whose concrete type I am not naming.*

Two workarounds existed and each cost the thing the pattern was for. A sum type **closes** the set,
which is the opposite of what these patterns provide. An array of closures works for a single-method
trait but cannot carry a multi-method one or the value's identity.

[[grammar/pudu]]'s `dynamic Trait` is that type:

```pudu
let listeners: Array[dynamic Listener] = [Logger{weight: 1}, Counter{weight: 5}, Silent{}]
for listener in listeners { total = total + listener.notify("tick") }
```

A fourth implementation added in another module needs no edit where the array is walked. That is the
open/closed property the patterns exist to provide, and it is why a sum type was never a substitute.

`test-fixtures/stdlib/UsesDynamic.pudu` carries nine of these as running properties: Observer,
Factory, match-arm widening, dynamic record fields, dynamic parameters, an open set, a recursive
heterogeneous Composite, Chain of Responsibility, and Abstract Factory — which is dynamic in both
directions at once, a `dynamic Maker` whose `create` returns a `dynamic Widget`.

## What this says about the language

Three things worth stating plainly.

**A pattern catalogue is a language's bug report.** Twenty-three named patterns, and most of them
name something Pudu does not need a name for. The ones that survive are the ones that are really
about program structure rather than about working around a missing feature.

**Static dispatch is the default and stays the default.** `dynamic` is the exception, written at the
one place it is needed, and everything else resolves at compile time. The `Iter` adapters are the
evidence: a decorator stack that costs nothing.

**The evaluator has no code about `dynamic` at all.** Values already carry their own type and method
dispatch already reads it, so the whole feature is static. A feature that needs no runtime support
is usually one that fits the language rather than one bolted onto it.

## Referenced by

[[architecture/_MOC]] · [[grammar/pudu]] · [[architecture/STDLIB]] · [[architecture/SEMANTICS]]
