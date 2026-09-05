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

**The query builder writes one dialect and never asks which is wanted.**
`Query.textOf` renders placeholders as `$1`, PostgreSQL's spelling, while every
driver already declares a `Placeholders` dialect that nothing consults. It does
not bite on either backend here — SQLite accepts `$N` as well as `?` — so the
two agree by luck rather than by design. A backend taking only `?` would be
refused by the database rather than by the builder, which is the wrong end to
find out at.

**The layers above the driver are tied to one backend.** `Std.Db.Query` and
`Std.Db.Repository` are written against `Std.Db.Rows`, the PostgreSQL session's
result type, not against `Std.Db.Driver.Rows`. A program reaching the driver
layer for SQLite cannot use the mapper above it, which is why `Orm.pudu` checks
the mapper against a result written down rather than one it fetched.
