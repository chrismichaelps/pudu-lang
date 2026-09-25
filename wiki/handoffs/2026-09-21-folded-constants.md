---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 271
tags: [handoff, evaluator, constants, startup, performance]
aliases: [2026-09-21-folded-constants]
---

# Folded Constants Handoff

## Objective

Resolve issue #271: constants folding already evaluated are bound when the program links instead of
being evaluated a second time, and the folded values travel with a module's stored checked product
so a warm run keeps them.

## Ownership and role transitions

1. **Runtime Engineer:** [[Eval Frozen]], [[Eval Program]], [[Eval Install]].
2. **Compiler Engineer:** [[Compiler Pipeline]] fold product, [[Compiler Program]], [[Compiler Cache]].
3. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff. No separate
   review agent is used at the repository owner's direction.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request.

## Contract

- Folding answers with its diagnostics and every constant whose value is plain data; a module with a
  folding diagnostic answers with none.
- Linking binds a folded constant under its name and evaluates every other initializer in
  declaration order. No environment, resource store, cell, native pointer, or runtime token leaves
  the fold.
- Folded values are stored in the checked product, keyed exactly as the product is.
- `run`, `test`, and `explain` link with folded values; the plain entry points still evaluate every
  initializer.

## Measurement

Optimized build, same host, full-stack example.

| Measure | Before | After |
|---|---:|---:|
| allocation to `listening`, warm cache | 111.2MB | 96.4MB |
| process start to `listening`, warm, best | 67.6ms | 58.5ms |
| allocation to `listening`, no cache | 568.8MB | 552.6MB |
| process start to `listening`, no cache, best | 363.1ms | 337.5ms |

## Completion evidence

- A fixture of thirteen constants — integers of three kinds, float, decimal, text, character,
  record, variant, tuple, array, map, and a function — runs identically from folded and evaluated
  constants; every plain-data constant folds, the function does not, and a tallied run does less
  work when linking from folded values.
- Cache equivalence covers the fixture, so stored folded values round-trip through a warm run.
- The optimized complete suite and the repository gate script pass.

## Exact next action

None for #271.

## Referenced by

[[handoffs/_MOC]] · [[Eval Frozen]] · [[Eval Program]]
