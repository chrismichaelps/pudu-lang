---
type: module
path: "@root/lib/Std/Db/Migrate.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, migrations, schema]
aliases: [Std Db Migrate]
---
# Std Db Migrate
## Purpose
Bring a schema from whatever it is to what the program expects, once, and never half way.
## Interface
A migration: a version, a name, and the statements that make it. The record of one that has been
applied. A plan: what has run, what has not, and what is wrong. Building a plan from what the
program holds and what the database reports, deciding it without a connection. Applying a plan.
Reading the record. The refusals, and what each says.
## Governance and algorithm
**A plan is decided without a database.** Given the migrations a program holds and the record a
database reports, what should happen next is a pure function of the two, so it is checked by
comparing values. Only applying one needs a connection.

**A migration that changed after it was applied stops everything.** The record holds a digest of the
statements as they were when they ran. A digest that no longer matches means the file was edited
after some database had already run it, so that database and a fresh one would not end up with the
same schema — and nothing later can detect that, because both will report the same version. It is
refused before anything runs rather than reported afterwards.

**A version that arrives late stops everything.** A migration numbered below one already applied
means two branches were merged without renumbering. Applying it now gives this database a history no
other database has, and running the same set in a different order is how two deployments diverge
while both report success. Refused rather than permitted with a warning: a warning is read after the
deployment.

**Each migration is applied in its own transaction.** A failure leaves every earlier migration
applied and the failing one absent, so the record always describes the schema. The alternative —
one transaction around all of them — is attractive until a statement that cannot run inside a
transaction appears, and then the whole arrangement has to change.

**Two processes starting together do not both migrate.** The lock is taken in the database rather
than in the program, because the processes racing are in different programs. A process that does not
get it waits and then finds there is nothing to do, which is the correct outcome and not an error.

**Any driver applies migrations.** `apply(client, driver, migrations)` runs over [[Std Db Driver]], so
SQLite and PostgreSQL applications share one path, and [[Std App Database]] exposes it as `migrate`
and as a start-up stage. The plan is decided before any lock is taken, so a refusal holds nothing.
Each pending migration then runs in its own driver transaction which, on PostgreSQL, first takes
`pg_advisory_xact_lock`: the lock ends with the transaction however it ends, and a pooled connection
returns to the pool with nothing attached. Inside the lock the record is read again, so a process
that waited finds its migration already applied and skips it. SQLite admits one writer at a time;
a second process reaching the same file mid-migration is refused as busy, and running it again finds
nothing to do.

**The session path releases its lock on every path.** `migrate(connection, migrations)` holds a
session-level advisory lock around the whole run and releases it after a refusal or a failed
migration as well as after success, speaking through the connection the rollback left.

**The record is created before it is read.** A first run against an empty database is the ordinary
case, not a failure. Its statement is written in SQL both bundled backends accept, with the applied
time defaulting to `current_timestamp`.

**Versions count from one.** A version of zero or below is refused as `Unnumbered` rather than
reported as arriving late against an empty record.

**One statement per entry.** SQLite's driver refuses a string holding several statements, so a
migration lists each statement as its own entry to stay portable.

**Verified against both backends.** `UsesMigrateApply` applies migrations to an in-memory SQLite
database and checks the order of statements a PostgreSQL driver is sent. Against a live PostgreSQL
14 server, both paths refused a changed migration and a failing one with no advisory lock left
behind, and four processes started together on one empty database applied three migrations exactly
once between them.
## Grill Log
- **Q:** Allow a migration to be edited after it has been applied? **A:** No. _Rationale:_ the
  database that ran the old text and one that runs the new both report the same version, so the
  divergence is undetectable from then on. _Rejected:_ re-running a changed migration; ignoring the
  digest.
- **Q:** Permit a lower version arriving late, since it is what merging branches produces? **A:** No.
  _Rationale:_ it is exactly what merging produces, and it is also exactly how two deployments end up
  with different schemas while both report success. Renumbering is a small cost paid once.
  _Rejected:_ out-of-order application with a warning.
- **Q:** Wrap every migration in one transaction? **A:** No. _Rationale:_ a partial failure would
  leave the record describing a schema that was rolled back, and some statements cannot run inside a
  transaction at all. _Rejected:_ a single enclosing transaction.
- **Q:** Take the lock in the program? **A:** No. _Rationale:_ the processes that race are different
  programs on different machines; a lock either of them holds alone is not a lock. _Rejected:_ a
  process-local guard.
- **Q:** Undo a migration? **A:** Not offered. _Rationale:_ an undo that is written is rarely run and
  therefore rarely correct, and one that is run in an emergency against real data is the worst
  possible time to discover that. A change that must be reversible is written as a further migration
  that reverses it, which is a migration like any other and is tested like one. _Rejected:_ a down
  statement per migration.
- **Q:** Hold one session-level lock for the whole run through a driver? **A:** No. _Rationale:_ a
  driver's client takes whichever pooled connection is free, so a lock taken by one call and released
  by another may be on different connections, and a lock left on a pooled connection stops every later
  migration everywhere. A lock scoped to each migration's transaction cannot outlive it. _Rejected:_
  session locks through `Driver.execute`.
- **Q:** Report a record that another process changed while this one waited? **A:** Yes, from inside
  the lock. _Rationale:_ the plan read before the lock can be stale by the time it is granted; reading
  again inside it is what turns a race into a skip rather than a duplicate. _Rejected:_ trusting the
  first read.
## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Session]] · [[Std Crypto]] · [[ADR-0016 An Application Is a Value]]
