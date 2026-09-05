# The database layers, against a real database

Two programs and two schemas. They are runnable rather than illustrative: each
check is worked out by hand and reported by name, so a wrong answer is a
failure a reader can act on rather than a number nobody reads.

```
pudu run examples/db/Orders.pudu   # the driver, against SQLite by default
pudu run examples/db/Orm.pudu      # the query builder and the row mapper
```

`Orders.pudu` writes `examples/db/orders.db` and `Orm.pudu` reads it, so run
them in that order. The file is gitignored.

## Against PostgreSQL

```
createdb orders
psql -d orders -f examples/db/postgres.sql
PUDU_DB_URL='postgresql://user:password@localhost:5432/orders' \
  pudu run examples/db/Orders.pudu
```

`schema.sql` is written to the intersection of both backends and is what
`Orders.pudu` applies itself; `postgres.sql` is the same order book written for
PostgreSQL alone, with the types and constraints a Postgres schema would
actually be given — `NUMERIC`, `CHECK`, `REFERENCES … ON DELETE CASCADE`, and
the two indexes the joins want.

## What is actually checked

The schema is an order book, because the shapes worth checking are the ones a
real one has: regions, customers, categories, products, orders, and the lines
belonging to an order.

`Orders.pudu` asks the driver for a three-table join with a grouped aggregate,
a left join whose right side is missing, a `NULL` column read straight from a
row, a value sent apart from the statement, an injection attempt that must
match nothing and leave the table standing, and two transactions — one rolled
back and one kept.

`Orm.pudu` asks the layers above it: what `Std.Db.Query` builds, exactly, as
text; that its identifier guard refuses a hostile table name, column name and
operator, which matters because a name cannot travel beside a statement the way
a value can; and what `Std.Db.Repository` does with a `NULL`, a column that is
not there, and a row past the end.

## What running them turned up

**Money comes back as a float on SQLite.** SQLite has no decimal type: a
`DECIMAL(12,2)` column has NUMERIC affinity, so the value is kept as a float
and a `SUM` of it answers as one. The amount is right, and the type is the
warning — `Orders.pudu` prints which of the two happened rather than hiding it,
because the difference only shows up after enough arithmetic to matter.

**The query builder wrote one dialect and never asked which was wanted.**
`Query.textOf` rendered placeholders as `$1`, PostgreSQL's spelling, while every
driver already declared a `Placeholders` dialect that nothing consulted. It did
not bite on either backend here, because SQLite accepts `$N` as well as `?` — so
running a `$1` statement and seeing it work proved nothing. `Query.textIn` now
spells a statement for a given dialect, and `Orm.pudu` runs the same statement
in both spellings so neither is passing by luck. `textOf` keeps its old
behaviour for callers that have no driver in hand.

**The mapper was tied to one backend.** `Std.Db.Repository` was written
against `Std.Db.Rows`, the PostgreSQL session's result type, so a program on the
driver layer could not use it at all. It now reads `Std.Db.Driver.Rows`, and
`Orm.pudu` maps rows it actually fetched from SQLite.

That is more than a type change. The session answers every column as text
because that is what the wire carries, while a driver answers what a value is,
so the mapper now takes a whole number from the number the backend decoded
rather than reading it back out of its digits — and it renders a number as text
where text was asked for, because refusing would mean the same query worked on
PostgreSQL and failed on SQLite. Bytes are the one thing it will not call text.

`Std.Db.Store` still speaks the session, which is what it is for; it converts at
its edges through `Db.asDriverRows`, the one description of how a session's
result becomes a driver's.
