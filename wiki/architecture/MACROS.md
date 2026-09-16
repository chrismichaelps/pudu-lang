---
type: architecture
tags: [architecture, semantics]
aliases: [Macro Design]
---

# Macro Design

## Decision

A macro is a **typed syntax transformer**: it declares what kind of syntax each parameter is, and its body is ordinary Pudu syntax that the expander substitutes into. Expansion happens before name resolution, and every binding a macro introduces is renamed so it cannot capture or be captured.

```pudu
macro twice(value: expr) = value + value

macro guard(condition: expr, body: block) = if !condition { } else body

fn run() -> Int { twice!(20) }
```

## Why not a token-tree matcher

[[grammar/pudu]] left the matcher syntax open. Two established shapes were available and neither is what Pudu should ship.

The C preprocessor has no kinds, no hygiene, and no parse: every problem it is known for — double evaluation, capture, precedence surprises — follows from substituting text before anything understands it. A macro that expands to `a + b` and is used in `2 * m!(x, y)` changes meaning silently.

A token-tree matcher fixes the parse and hygiene but reports failure in terms of itself: "no rule expected token `,`" describes the matcher's state, not the reader's mistake. Its power comes from pattern matching over unparsed trees, which is also what makes its diagnostics and its hygiene rules hard to explain.

Typed syntax parameters keep the useful half of both. A parameter declares that it is an expression, an identifier, or a block, so:

- a mismatch is reported against the call — "argument 2 must be an identifier" — rather than against a matcher;
- the argument is already parsed, so precedence cannot surprise the caller;
- the expander knows exactly which identifiers the macro introduced, which is what makes hygiene mechanical rather than a convention.

## Rules

- A macro is expanded before name resolution, matching [[architecture/SEMANTICS]]'s ordering, so the phases that follow never see a macro call.
- A call is written with `!` — `twice!(20)` — so a reader can see that expansion happens without knowing which names are macros.
- Each parameter declares its kind: `expr`, `ident`, or `block`. An argument of the wrong kind is a diagnostic at the call.
- Arity is exact. A macro takes what it declared.
- Every binding introduced inside a macro body is renamed at each expansion, so it can neither capture a caller's name nor be captured by one. This is the hygiene rule [[grammar/pudu]] states, and the expander enforces it rather than trusting the macro author.
- Expansion is bounded. A macro that expands into itself exhausts the depth budget and reports where the expansion started.
- Expanded syntax carries the call site's span, so a diagnostic inside an expansion points at the call the reader wrote.

## What is still open

- **Repetition.** A macro cannot yet take a variable number of arguments. The open question is not the syntax but whether repetition is needed at all: Pudu has `Array` values and compile-time functions, so a macro taking one `expr` that happens to be an array literal may cover the cases repetition exists for in other languages. That comparison should be made against real uses before a repetition syntax is added, because a syntax added first would be the one everything is then forced through.
- **Definition-site resolution for free names.** A name the macro body *mentions* still resolves where the macro is expanded. Introduced bindings are hygienic today, which is the rule the grammar states; full definition-site resolution needs resolution and expansion to share a representation, and arrives with that slice.
- **Item and statement macros.** Expression macros come first because they compose with everything already checked. A macro that expands to a declaration changes what the module contains, which interacts with the two-pass collection in [[Name Resolution]] and deserves its own decision.

## Grill Log

- **Q:** Token trees or typed parameters? **A:** Typed parameters. _Rationale:_ the diagnostics describe the call rather than the matcher, and hygiene becomes mechanical because the expander knows which identifiers came from the body. _Rejected:_ C-style textual substitution, which has no parse and no hygiene; `macro_rules!`-style matchers, whose power is pattern matching over unparsed trees and whose errors describe matcher state.
- **Q:** Should a macro call look like a call? **A:** No; it is written with `!`. _Rationale:_ expansion changes what the reader is looking at, and hiding that behind ordinary call syntax makes a name's meaning depend on knowledge the reader may not have. _Rejected:_ implicit macro calls; a leading sigil, which reads as punctuation noise at every use.
- **Q:** Implement repetition now? **A:** No, and say why. _Rationale:_ [[grammar/pudu]] deferred it, and the honest reason to keep deferring is that arrays plus compile-time functions may already cover the need — adding syntax first would foreclose that. _Rejected:_ copying `$(...),*` because it is familiar.
- **Q:** Why not build macros on `comptime fn` over syntax values? **A:** Because that needs the syntax tree reified as runtime values, which is a larger decision about what a `Expr` value is and how it is constructed. It remains the natural next step, and typed parameters are forward-compatible with it: a typed parameter is exactly the argument such a function would receive.

## Referenced by

[[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Macro Expansion]]
