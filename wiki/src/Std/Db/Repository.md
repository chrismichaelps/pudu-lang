---
type: module
path: "@root/lib/Std/Db/Repository.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, rows, mapping]
aliases: [Std Db Repository]
---
# Std Db Repository
## Purpose
Turn rows into the program's own values, and say which column was wrong when one is.
## Interface
Reading one column of one row as text, a whole number, a count, a truth, or a value that may be
absent. What went wrong, naming the column. Turning every row into a value, exactly one row, or at
most one. Counting what a statement changed. A repository: the operations a program has over one
kind of thing, held as a value.
## Governance and algorithm
**A column that is not there and a column that held nothing are different answers.** The layer
beneath cannot tell them apart — both arrive as an absence — and inheriting that means a mistyped
column name reads as a row with a missing value, which is a different bug found much later and
somewhere else. Here the column list is consulted first, so a name nothing matches says so.

**Exactly one is a question that can fail two ways, and both are reported.** A lookup that expected
one row and found none is not the same as one that found several, and answering the first of several
is how a program silently acts on the wrong record. Both are refused, and a caller that genuinely
wants the first of several asks for that.

**A mapping is a pure function from a result and a row number.** So a program's mapping is checked
by building a result and comparing values, with no database involved — which matters, because
mapping is where the errors are and a database is the slowest way to find them.

**A repository is a record of functions.** No proxying an interface into an implementation, no
generating a query from a method name: what a repository does is what somebody wrote in it. That
also means a repository over a different backing — a fake for a test, a cache in front — is the same
record with different functions, rather than a mechanism this module has to provide.

**A failure names the column, not the value.** The value came from the database and may be anything;
putting it in a message is how a message reaches a log with something in it nobody expected. The
column name is what a program acts on.
## Grill Log
- **Q:** Let a missing column read as an absent value, since the layer below does? **A:** No.
  _Rationale:_ that turns a typo into a data condition, and it is found later and further away.
  _Rejected:_ inheriting the conflation.
- **Q:** Have the one-row read answer the first of several? **A:** No. _Rationale:_ that is how a
  program acts on the wrong record without anything appearing to go wrong. _Rejected:_ taking the
  first; taking the last.
- **Q:** Derive a query from the name of a repository operation? **A:** No. _Rationale:_ it requires
  reflection this language does not have, and where it exists it turns a rename into a silent change
  of behaviour. _Rejected:_ name-derived queries.
- **Q:** Include the offending value in a failure? **A:** No. _Rationale:_ it came from the database,
  it may be anything, and a message is a place values end up being rendered. The column is what a
  caller acts on. _Rejected:_ echoing the value.
## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Query]] · [[Std Db Session]] · [[architecture/WEB]]
