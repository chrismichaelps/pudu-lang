---
type: decision
status: Accepted
date: 2026-08-28
tags: [decision, syntax, patterns, control-flow, failure]
aliases: [ADR-0011, Propagation Over Re-Matching]
---

# ADR-0011 — Propagation over re-matching

**Status: Accepted.**

## Context

`match` is the complete branching form, and completeness makes it the default reach. A writer who
needs one value out of a carrier spells every arm, including the arm that carries failure onward
unchanged. Do that twice in one function and the code turns a corner.

Counted across `lib/` before this decision: 248 `match` keywords, 26 of them nested two or more
deep, 49 arms spelled `case Err(e) => Err(e)`, 20 spelled `case None => None` — and **no use of `?`
at all**, in a standard library whose compiler had implemented `?` in the parser, the resolver, the
checker, the evaluator, the macro expander, and the REPL outline. Sixty-nine propagations were
written out by hand beside an operator that performs all sixty-nine.

`Std.Time.toDate` was the shape at its worst: twenty-one lines, three levels of indent, and every
failure arm identical to the value it received.

The arms were not the cost. The cost is that a reader must check each one to learn it decides
nothing.

## Decision

State the rule, supply what makes it reachable everywhere, and say so where it is missed.

**The rule.** A `match` arm that reconstructs its own scrutinee's failure unchanged is not a
decision. It is punctuation. Where every failure arm passes through, propagate. Where one success
continues and one fallback ends, bind and leave. Reserve `match` for where the arms genuinely
differ.

**`?` carries both carriers.** Which one is meant is read from the enclosing function's declared
result, never from the target. In a function returning `Result`, `Ok(v)?` yields `v` and `Err(e)?`
returns `Err(convert(e))`. In a function returning `Option`, `Some(v)?` yields `v` and `None?`
returns `None`. Because the return type has already said which carrier is in play, one operator
serves both with no token to disambiguate them, and a target that is not that carrier stays an
ordinary type error rather than a rule of its own. A return type that is neither is `E3011`. An
unannotated result is inferred as `Result`, because the `Ok` and `Err` in such a body decide it.

**`let PATTERN = EXPRESSION else BLOCK`** binds a refutable pattern for the remainder of the
enclosing block. The `else` block must not fall through; `E3036` says so when it can. That
divergence is what earns the binding its scope, and it is checked rather than trusted. Divergence
is asked of the block's ending rather than its type: a block ending in `return` has no result
expression, and a block without one is `()` — the same answer a block ending in `0` would give.
A syntactically irrefutable pattern is `E1057`.

Which form a `let` opens is settled by the token after it, since a binding names a value: a
lowercase identifier is always the ordinary binding, and a constructor path, tuple, record,
literal, or `_` is always the pattern form. One token of lookahead decides it, with no backtracking.

**`W3003`** names a `match` whose every failure arm rebuilds what it received, when the enclosing
return type carries the same shape, and gives the `?` that replaces it. A warning, not an error: it
names a better spelling of working code rather than condemning it.

The two new surface nodes stay distinct through the tree, as ADR-0010 kept `IfLetExpression`, so
`:ast`, the formatter, the REPL outline, and every diagnostic describe what the reader wrote.
Each semantic phase gains one shallow dispatch case and delegates the pattern rule to the machinery
`match` and `if let` already share. No second pattern semantics is introduced.

## Consequences

- Dependent carrier code is one-dimensional without weakening exhaustive `match`.
- The standard library speaks the vocabulary it ships. `Err` pass-throughs fell from 49 to the 7
  that are `Std.Result`'s own combinator definitions; nested `match` fell from 26 to those that
  decide something.
- `if let` and `let … else` are complementary and neither subsumes the other: the first is for a
  value used once, the second for a value every following step depends on.
- Three error codes and one warning code are claimed: `E1057`, `E1058`, `E3036`, `W3003`.
- The rule reaches the combinators themselves. `Std.Option.map` is `Some(transform(value?))` and
  `Std.Result.flatten` is `value?`. An earlier draft exempted these as definitions that could not be
  written in terms of themselves; that was wrong, and `W3003` is what said so. `?` is a compiler
  primitive rather than a `Std` function, so a combinator reaching for it is not circular. `W3003`
  is now silent over the whole of `lib/`.
- An arm whose failure branch *transforms* what it received keeps its `match`. `Std.Result.mapErr`
  and `Std.Text.Parse.orElse` decide something, and that is the line the rule draws.

## Rejected alternatives

- **Operator notation for `Set`** — `|`, `&`, `\`, `<=`. `Std.Set` already carries the complete
  algebra by name: `union`, `intersection`, `difference`, `symmetricDifference`, `isSubsetOf`,
  `isSupersetOf`, `isDisjointFrom`, `cartesian`, `unionAll`, `intersectAll`. Symbols would buy
  characters at the cost of the named vocabulary this decision exists to defend.
- **A second, `Option`-specific propagation operator** — which [[ADR-0010]] rejected, and this does
  not introduce. `?` learning that `Result` and `Option` are both carriers with one failure shape
  is not a second operator.
- **A binding block that short-circuits every `let` inside it** — expressive, but it is the
  order-dependent second scope grammar ADR-0010 refused, and `?` with `let … else` covers the
  motivating code without it.
- **Pattern conditions inside `&&` and `||`** — unchanged from ADR-0010; nothing here reopens it.
- **`?` on `Task`** — a task has no failure arm at the await site. The grammar already states that
  `task.await?` is a type error, and it stays one.
- **Making the redundant arm an error rather than a warning** — it would break working code to
  improve its spelling, and an arm that only looks redundant would have no recourse.

## Referenced by

[[decisions/_MOC]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[ADR-0010]] ·
[[Type Check Rule]] · [[Type Check Statement]] · [[Evaluator]] · [[Eval Operator]] ·
[[Syntax Tree]] · [[Parser Declaration Block]]
