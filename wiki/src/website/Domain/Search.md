---
type: module
path: "@root/website/src/Domain/Search.pudu"
fidelity: Active
tags: [website, domain, search, query]
aliases: [website Domain Search]
---
# Website Domain Search

Defines the parsed Pudu API query independently from HTTP and HTML. A query carries ordinary name
terms, an optional normalized Pudu type shape, module and declaration-kind filters, and exact-name
intent. It also owns type normalization and module-leaf helpers shared by ranking tests.

Resolved Grill Log: recognize only `module:`, `kind:`, and `is:exact`; preserve concrete Pudu type
constructors, references, mutability, constraints, and arrow order; normalize only insignificant
whitespace, search case, and single-letter generic placeholders; and keep unknown filters as ordinary
terms instead of silently discarding user input.
