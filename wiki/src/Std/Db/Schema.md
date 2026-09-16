---
type: module
path: "@root/lib/Std/Db/Schema.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, schema, columns]
aliases: [Std Db Schema]
---
# Std Db Schema
## Purpose
Make a column a name the compiler knows, so writing one wrong is a compile error and writing one at
all is offered by the editor.
## Interface
A column, carrying the table it belongs to, its name, and the type of what it holds. Declaring one.
A table's name. What a value must be to travel as a parameter, and the implementations for the types
a column ordinarily holds. The comparisons a condition may use, as values rather than as text.
## Governance and algorithm
**A column is a value with a type, not text inside a name.** A program declares its table once as a
module of columns, and every query names them through it. Three things follow, and they are the
whole point.

The editor offers them, because they are ordinary module members and the language server already
completes those — nothing here is special-cased, and nothing has to parse a method name to guess
what a program meant.

A column that does not exist is a **compile error**, at the place it is written. The established
framework in this space derives a query from the name of a method, which is clever and buys the same
completion through an editor plugin that understands the naming scheme — but a property name that is
wrong there is found when the method runs. Between a compile error and a runtime one there is no
contest.

And the value is checked against the column. A column of text compared against a number does not
type, so the mistake is caught rather than sent to the database to be refused, or worse, silently
coerced.

**How a value travels is a contract, not a rendering.** A value bound to a parameter is written by
`Bindable`, which is separate from how a value is shown to a person: showing text quotes it, and a
quoted value in a parameter is a different value. Conflating those is the kind of thing that works
in every test and is wrong in production.

**A comparison is a value too**, so the same completion and the same compile-time check cover the
operator, and there is no text for one to arrive as.

**Nothing here reads a schema from a database.** A program says what its tables are, and the
statement it wrote and the schema it declared are checked against each other rather than both
against a database that has to be running. Reading a live schema would move the check to a place
where it needs a connection, which is where it stops being done.
## Grill Log
- **Q:** Derive the query from the name of a function, as the established framework does? **A:** No.
  _Rationale:_ it needs to parse a name into meaning, which needs the reflection this language does
  not have; and where it exists, a wrong property name is found when the method runs rather than
  when it is written. Its own documentation notes the names become unwieldy. _Rejected:_ name-derived
  queries.
- **Q:** Read the columns from the database so they cannot disagree with it? **A:** No, not here.
  _Rationale:_ that moves the check to somewhere that needs a live connection, which is where checks
  stop happening. A program declares what it expects; a migration is what makes the database agree.
  _Rejected:_ schema reflection at startup.
- **Q:** Use `show` to write a value into a parameter? **A:** No. _Rationale:_ showing is for people
  and quotes text; a quoted value in a parameter is a different value, and the mistake passes every
  test written with numbers. _Rejected:_ reusing the display rendering.
- **Q:** Let a column be built from arbitrary text at run time? **A:** It can be, and that path goes
  through the name check in [[Std Db Query]] like any other. _Rationale:_ a program reading a column
  choice from a request exists; it should be explicit and checked, not the ordinary way.
## Referenced by
[[src/Std/_MOC]] · [[Std Db Query]] · [[Std Db Repository]] · [[Std Db]] · [[ADR-0016 An Application Is a Value]]
