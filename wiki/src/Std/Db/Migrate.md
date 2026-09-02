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

**The record is created before it is read.** A first run against an empty database is the ordinary
case, not a failure.
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
## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Session]] · [[Std Crypto]] · [[ADR-0016 An Application Is a Value]]
