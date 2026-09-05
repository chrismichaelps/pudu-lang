---
type: module
path: "@root/lib/Std/App/Database.pudu"
fidelity: Active
tags: [module, stdlib, database]
aliases: [Std App Database]
---
# Std App Database

## Purpose
An application-owned PostgreSQL pool.

## Interface and algorithm
A shared backend-neutral client starts and stops through explicit application stages. A lifecycle
mutex serializes start/stop, while the selected driver owns query concurrency and connection reuse.
Startup refuses an already open client; shutdown clears admission then closes it. A failed publish
closes the newly opened client. No global registration or implicit schema synchronization occurs.

## Resolved Grill Log
- **Q:** Silently ignore unsupported connection settings? **A:** No; reject before network I/O.
- **Q:** Let handlers interpolate values into SQL? **A:** No; query binds parameters separately.
- **Q:** Claim live database conformance without execution? **A:** No; this delivery is unvalidated at the user's direction.

## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Db]] · [[Std Db Session]] · [[2026-09-05-database-framing]]


## Backend-neutral revision

The resource stores a Driver.Driver, connection string, pool size and optional Driver.Client.
`withDriver` prepares any supplied driver; `withDrivers` selects by URI from an explicit driver
array. `create` selects from the bundled PostgreSQL and SQLite drivers. `fromConfigWith` accepts a caller-selected driver;
`fromConfig` selects from the bundled drivers. Public queries and results use Driver.Value,
Driver.Rows and Driver.Error, with no PostgreSQL session types. Lifecycle synchronization is
unchanged. Driver implementers own thread-safe query admission, pooling and close behavior.

## Application usage

Declare `database.url` before applying environment overrides to read `DATABASE_URL`.
For local PostgreSQL, its value can be
`postgresql://app:password@127.0.0.1:5432/app?sslmode=disable`.
Keep real credentials out of source control and avoid printing resource/configuration records.

```pudu
import Std.App as App
import Std.App.Config as Config
import Std.App.Database as Database
import Std.Db.Driver as Driver
import Std.Db.Postgres as Postgres
import Std.Http as Http
import Std.Http.Server.Route as Route
import Std.Http.Server.Reply as Reply
import Std.Result as Result

fn application() -> Result[Int, Str] {
  let settings = Config.withEnvironment(&Config.declaring(&[
    ("database.url", ""), ("server.host", "127.0.0.1"), ("server.port", "8080")
  ]))
  let database = Result.mapErr(Database.fromConfigWith(Postgres.driver(), &settings, "database.url", 4),
    fn(problem: Driver.Error) -> Str { problem.message }) ?
  let routes = Route.routing(&[
    Route.get("/database", fn(_request: Route.Request) -> Http.Response {
      match Database.query(&database, "SELECT $1::text AS message", &[Driver.TextValue("connected")]) {
        case Ok(rows) => Reply.text(200, show(rows.rows))
        case Err(_) => Reply.text(503, "database unavailable")
      }
    })
  ])
  let application = App.using(&App.over("database-app", &settings, &routes),
    Database.stage(&database, "database"))
  Result.mapErr(App.run(&application), fn(problem: App.AppError) -> Str { App.explain(&problem) })
}
```

Replace `Postgres.driver()` with another concrete driver and use that database's SQL dialect and
placeholder convention. Handler/lifecycle APIs and result types stay the same. `withDrivers`
selects from a caller-provided array using the URI scheme; duplicate matches fail instead of
choosing by array order. Driver implementations can live in application packages.

No example was compiled or executed in this delivery. The bundled implementations are
PostgreSQL and SQLite; MySQL and other native adapters remain implementation work, not aliases to
PostgreSQL. [[Std Db Store]], [[Std Db Query]], and migrations currently remain PostgreSQL-specific
and do not yet consume the generic driver contract.

## Selecting the backend through configuration

`Database.fromConfig(&settings, "database.url", 4)` selects the bundled driver by URI scheme.
Use `postgresql://...?...` for PostgreSQL or `sqlite:/absolute/path/app.db` for SQLite.
`Database.create("sqlite::memory:", 1)` creates an isolated in-memory SQLite resource when started.
`Database.bundledDrivers()` returns the explicit built-in list; append another package's driver
and pass that list to `withDrivers` to extend selection. Unknown or ambiguous schemes fail.
The SQL dialect and placeholders still belong to the chosen database.
