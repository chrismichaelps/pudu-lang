---
type: module
path: "@root/test/Pudu/Compiler/Program/AttributeSpec.hs"
fidelity: Active
tags: [module, test, attributes]
aliases: [Program Attribute Spec]
---
# Program Attribute Spec

## Purpose and interface

Export `testDeclaredAttributes`, one IO property registered in [[Program Spec]] as "every attribute names a declaration of its kinds".

## Algorithm and invariants

Compile six fixtures with the shared complete-program runner [[Program Test Common]] and compare each fixture's exact diagnostic code list:

| Fixture | Expected codes | Refusal |
|---|---|---|
| [[src/test-fixtures/attributes/DeclaredAttribute]] | none | declared attributes with arguments of their kinds are accepted |
| [[src/test-fixtures/attributes/UnknownAttribute]] | E3104 | an attribute nothing declares |
| [[src/test-fixtures/attributes/WrongAttributeArgument]] | E3105 | an argument of the wrong literal kind |
| [[src/test-fixtures/attributes/conflict/Main]] | E3106 | a second meaning for one attribute name |
| [[src/test-fixtures/attributes/UndeclaredRead]] | E3104 | a derive reading an undeclared attribute |
| [[src/test-fixtures/attributes/UnsupportedKind]] | E1069 | a parameter kind that is no literal |

Each fixture must produce exactly its listed codes, so a missing or extra diagnostic fails the property.

## Resolved Grill Log

- **Q:** Compare exact code lists or only presence? **A:** Exact lists. An extra diagnostic is as wrong as a missing one, so each fixture is pinned to its single refusal.
- **Q:** One property for six checks? **A:** One registry entry per attribute feature; the fixtures share the declaration rules and run through one runner.

## Referenced by

[[Program Spec]] · [[Declared Attributes Delivery]] · [[Type Check Attribute]] · [[Program Test Common]]
