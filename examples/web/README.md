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
  -d '{"title":"First note","body":"Hello, café"}'
```

`DATABASE_URL`, `SERVER_HOST`, `SERVER_PORT`, and `SERVER_CONNECTIONS` override declared defaults.
The framework also reads `app.toml` and command-line settings through Config.discover.
Use a PostgreSQL connection URI for the bundled PostgreSQL driver; the example chooses its
parameter placeholders from the selected driver. Existing database permissions must allow table
creation and querying. Connection settings and credentials are never rendered by handlers.

The database stage starts before schema creation and closes during reverse teardown. The schema
stage is bootstrap only; it does not upgrade existing tables. Titles are unique. Invalid media,
JSON and fields return 415, 400 and 422 respectively. Database failures are generic responses.

This example has not been executed or validated. Authentication, editable browser forms,
pagination and deployment configuration remain application work; it is not a production template.
