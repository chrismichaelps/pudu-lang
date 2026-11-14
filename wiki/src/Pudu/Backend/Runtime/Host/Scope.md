---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Scope.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Scopes]
---
# Native Host Scopes

Export the family's runtime parts and their prerequisites.

Structured task scopes: the tasks started while a scope is open are its children, an awaited child is let go, and the rest are joined in the order they were started when the scope is left.

## Resolved Grill Log

The nursery is per thread and nests. Joining is the scope's only exit, on every way out.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
