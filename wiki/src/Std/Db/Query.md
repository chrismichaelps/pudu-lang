---
type: module
path: "@root/lib/Std/Db/Query.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, query, injection]
aliases: [Std Db Query]
---
# Std Db Query
## Purpose
Build a statement in which a value cannot become part of what runs.
## Interface
A statement: the text, and the values that go beside it. Beginning one from a table. Choosing
columns. A condition, and further conditions joined by and or by or. Membership in a list. Ordering,
a bound, and a starting point. Inserting, updating, and deleting. Reading back the text and the
values a statement holds. A name, checked, for the places a parameter cannot go. What a refusal
says.
## Governance and algorithm
**A value can only ever become a parameter.** There is no call that places one into the text. A
condition takes a fragment and a value, and appends a placeholder — so the text a statement holds is
built only from parts the program wrote, and everything that came from outside travels beside it.
This is the same move as the escaping decision in [[Std Html]]: the failure is removed by making it
unrepresentable rather than prevented by a rule to remember at every call site.

**A name is not a value, and that is where the real risk is.** A table or column cannot be a
parameter — no database accepts one — so a builder that lets a name come from a request has an
injection point that parameters do not close, and this is the hole most query builders leave open.
A name is admitted only when it is made of letters, digits, and underscores and does not begin with
a digit; anything else is refused rather than quoted, because quoting is a guess about the dialect
and refusing is not. A program needing a name that cannot be written that way chooses it from a list
it wrote, which is a different operation and reads like one.

**Placeholders are numbered as they are added.** The count is held in the statement rather than
recomputed from the text, because recomputing means parsing the text, and a builder that parses its
own output has re-entered the problem it exists to avoid.

**A statement is a value and running it is somewhere else.** So the whole of this module is checked
by comparing text and parameters, and a program can see what it is about to run.
## Grill Log
- **Q:** Offer a call that takes a finished statement as text, for what the builder does not cover?
  **A:** Yes, and it takes no values through the same door — a caller with a statement of their own
  passes it and its parameters separately, exactly as here. _Rationale:_ a builder that cannot
  express something forces a way around it, and the way around should still keep values apart.
  _Rejected:_ a call that formats values into text.
- **Q:** Quote a name that is not admissible rather than refusing it? **A:** No. _Rationale:_ quoting
  correctly depends on the dialect, and a quoted name that was wrong is an injection that looks
  handled. _Rejected:_ escaping identifiers.
- **Q:** Number placeholders by counting them in the text? **A:** No. _Rationale:_ that means parsing
  the text this module built, and a builder that parses its own output has re-entered the problem it
  exists to avoid — a placeholder inside a string literal would be counted. _Rejected:_ deriving the
  count from the text.
- **Q:** Let a condition be built from a column and an operator chosen at run time? **A:** The column
  goes through the name check and the operator comes from a stated set. _Rationale:_ an operator
  from outside is as dangerous as a name from outside and there are few of them, so a set costs
  nothing. _Rejected:_ an arbitrary operator string.
## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Repository]] · [[Std Html]] · [[ADR-0017 What the Web Layer Refuses]]
