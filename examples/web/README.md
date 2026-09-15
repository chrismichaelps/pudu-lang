# Database-backed web application

Run from the repository root with a Pudu executable available:

```sh
pudu run examples/web/Notes.pudu
```

The service binds `127.0.0.1:8080` and persists notes in `notes.db`. SQLite must be installed.
Open `/` for HTML and `/api/notes` for JSON. Create a note through the API:

```sh
curl -X POST http://127.0.0.1:8080/api/notes \
  -H 'Content-Type: application/json' \
  -H 'Sec-Fetch-Site: same-origin' \
  -d '{"title":"First note","body":"Hello, café"}'
```

The `Sec-Fetch-Site` header is required. A request that changes something must say it came from this
site, and one that says nothing is refused with 403: an old client and a forged cross-site request
look the same, and only refusing is safe for both. Browsers send the header themselves.

`DATABASE_URL`, `SERVER_HOST`, `SERVER_PORT`, and `SERVER_CONNECTIONS` override declared defaults.
The framework also reads `app.toml` and command-line settings through Config.discover.
Use a PostgreSQL connection URI for the bundled PostgreSQL driver; the example chooses its
parameter placeholders from the selected driver. Existing database permissions must allow table
creation and querying. Connection settings and credentials are never rendered by handlers.

The database stage starts before the schema stage and closes during reverse teardown. The schema
stage is `Database.migrationStage`: it applies numbered `Std.Db.Migrate` migrations, records each
one as it commits, and runs nothing on a restart. A later change to the table is a further migration,
never an edit to the first; an edited migration stops start-up with a message saying so. Titles are
unique. Invalid media, JSON and fields return 415, 400 and 422 respectively. Database failures are
generic responses.

Run against SQLite: a note posted with the command above is listed after a restart, and the
second start records no further migration. Authentication, editable browser forms, pagination and
deployment configuration remain application work; it is not a production template.
