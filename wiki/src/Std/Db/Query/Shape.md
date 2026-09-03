---
type: module
path: "@root/lib/Std/Db/Query/Shape.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, query, joins]
aliases: [Std Db Query Shape]
---
# Std Db Query Shape
## Purpose
A whole query written as one value, so the query is what a reader sees rather than the order it was
assembled in.
## Interface
A select: what it reads from, what it answers with, what it joins, what it keeps, how it groups,
what it keeps of the groups, what it orders by, how much of it is wanted, whether duplicates go, and
whether the rows are held. Turning one into a statement. Helpers for each part — a picked column, an
aggregate, a name to answer under, each kind of join, each kind of condition, an ordering, a bound.
Two results combined. A named result the rest of a statement reads from.
## Governance and algorithm
**A query is a value, not a sequence of calls.** The first design here assembled a query by calls
that each took the previous one, and the result read inside out: the thing a reader wants to know
first — what it reads from and what it answers with — ended up furthest in, and the visible shape of
the code was the shape of the nesting rather than anything about the query. Written as one record it
reads in the order it is thought of, and the parts a query does not need are empty rather than
absent. That is not a matter of taste: a reader checking whether a query is right has to be able to
see all of it, and thirteen levels of parentheses is a place mistakes hide.

**Everything that could be a name is checked in one place.** The helpers that build the parts do no
checking; `select` does all of it, on every part, when it turns the record into a statement. So there
is one place to read to know what is admitted, and a part built and never used cannot fail on its
own.

**The clauses come out in the order the language reads them**, whatever order the record was written
in. What is built is what runs, rather than something a server has to be lenient about.

**Where nothing sorts is stated.** A server's default for that differs by direction, so a page that
reorders itself when a column becomes nullable is a bug nobody goes looking for.

**This does not cover the whole of the language and does not try to.** Window frames, grouping sets,
lateral joins, and recursive traversal are not here. What is not covered goes through the text form,
which still keeps values apart — so the escape hatch does not give up the property the builder
exists for. Modelling the whole grammar would produce an interface as large as the grammar and no
safer than writing it out.
## Grill Log
- **Q:** Build a query by calls that each take the last one? **A:** No — that was the first design
  and it was wrong. _Rationale:_ it reads inside out, so the query a reader wants to check is
  scattered across the nesting rather than visible at once, and every level carries an unwrap.
  _Rejected:_ nested builder calls; chained methods.
- **Q:** Check each part where it is built? **A:** No; check every part in `select`. _Rationale:_
  one place to read, and a part that was built and never used does not fail on its own.
  _Rejected:_ checking in the helpers.
- **Q:** Model window functions and grouping sets too? **A:** No. _Rationale:_ the interface would
  approach the size of the grammar while the text form already covers them without giving up
  parameters. A builder earns its place on the shapes applications actually write. _Rejected:_ full
  grammar coverage.
- **Q:** Default the locking clause to waiting? **A:** It is written in the record and both are
  offered. _Rationale:_ a queue wants to skip what another worker holds and a report wants to wait;
  neither is the obvious default. _Rejected:_ choosing for them.
## Referenced by
[[src/Std/_MOC]] · [[Std Db Query]] · [[Std Db Schema]] · [[Std Db Store]] · [[Std Html]]
