---
type: module
path: "@root/test-fixtures/stdlib/UsesSiteAll.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, web]
aliases: [Uses Site All]
---

# Uses Site All

## Purpose and interface

Executable fixture for [[Std Site]] in a temporary directory. Its `main` returns 40 held assertions:
path-to-file mapping with and without a content type (pages named like files included), every unsafe
path refused; a static build with a non-200 page and an escaping path refused, public files copied,
binary bodies written byte for byte; a rebuild writing nothing, then exactly the one changed page; one
worker and eight writing the same files; a Vercel build with its static directory and routes; the
configuration with a fallback, a 404 page, and neither; defaults and host detection; and each
refusal of unusable options.

## Referenced by

[[Std Site]] · [[Runtime Evaluation Spec]]
