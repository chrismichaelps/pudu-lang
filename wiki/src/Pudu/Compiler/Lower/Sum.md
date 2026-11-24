---
type: module
path: "@root/src/Pudu/Compiler/Lower/Sum.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Sum]
---
# Compiler Lower Sum

## Purpose and interface

Export `lowerVariant` and `variantAt`.

- A name or call is a variant only when the checker typed its span as a sum
  with a variant of that name taking that many positional members, so a local
  or function of the same name is never mistaken for one. Record variants go
  through [[Compiler Lower Record]].
- Payload members run left to right into `CoreConstruct`, named "0", "1", ...
  A Never member stops the variant after the members before it ran.

## Grill Log

- **Q:** Decide a variant from its spelling? **A:** No; the checker's type at
  the span decides, which keeps shadowing and qualification (`Shape.Circle`)
  exactly as checking resolved them (#536).
- **Q:** Why stop at a Never payload? **A:** The evaluator stops there too; the
  later payloads never run and no value is built.

## Referenced by

[[Compiler Lower Body]] · [[Native Emission Coverage]] · [[src/_MOC]]

## Dynamic payloads (#846)

A variant payload declared `dynamic` widens a value of an implementing type
to the declared type, at the argument's position, before `CoreConstruct`.
Resolved Grill Log: the variant's declared field type chooses the widening;
a Never payload still stops later payloads.

## Runtime layouts in sum payloads (#956)

Resolved Grill Log: Positional and named constructors share payload projection. They choose the physical layout of the selected variant and preserve the other variants.

## Concrete held payload fields

Resolved Grill Log. A retained value with one known layout can differ
from the checked field just as a runtime alternative can. First apply
the declared projection where valid. Keep a different concrete native
layout in the selected variant so nested patterns read the value that
construction actually received. [[Compiler Lower Match]]

## Retained positional constructors

Resolved Grill Log. Use the settled constructor type to admit the
owner, label and arity. Generate a capture-free callable that uses
the same payload construction as a direct call. Rebuild the callable
from its original sum layout when a stored call supplies other native
parameter layouts. [[Core Closure Identities]] · [[Compiler Lower Lambda]]
