# Examples

Programs that show what the language does, run by hand rather than by CI.

A gate has to run everywhere. These do not: `raylib/Window.pudu` opens a window,
which needs a display, and a check that cannot run on a headless runner is not
one this repository can rely on. What runs in CI instead is
`test-fixtures/integration/UsesRaylib.pudu`, which reaches the same installed
library through the same boundary without asking for a screen.

So these are here to be read and to be run once, not to be trusted as proof.
The formatter and the checker still cover every file here, because an example
that does not compile is worse than no example. One file is run by the test
suite: `media/ConfigChecks.pudu`.

Run every command from the repository root.

| Folder | What it is | Needs |
| --- | --- | --- |
| [`fullstack/`](#fullstackmainpudu) | a task board: HTML pages and a JSON API over one database | SQLite |
| [`social/`](#socialmainpudu) | a feed with posts, approvals and replies, rendered on the server | SQLite |
| [`web/`](#web) | a notes service, and streaming server rendering | SQLite or PostgreSQL |
| [`db/`](#db) | the database layers checked against a real database | SQLite, optionally PostgreSQL |
| [`media/`](#mediastudiopudu) | audio, video timing and a desktop window together | a display |
| [`raylib/`](#raylib) | a window and a game drawn by a C library | raylib and a display |

## fullstack/Main.pudu

A task board: a page a person uses and an API a program uses, over one database,
from one command.

```bash
pudu run examples/fullstack/Main.pudu        # listens on 127.0.0.1:8080
pudu run examples/fullstack/Main.pudu 9000   # or on a port you name
curl http://127.0.0.1:8080/api/tasks
```

Worth reading for the layout. `Main.pudu` only says which URL reaches which
function. `Service/` decides what a task is, `Db/` is the one module that
writes SQL, `View/` draws the page, and `Web/` and `Api/` are the two edges.
Web answers with pages and redirects, Api with JSON and a status, and both
call the same commands underneath.

The schema is a numbered migration applied at start-up with
`Database.migrate`, so restarting against the same database runs nothing. The
database is in memory, so every start begins from the seeded tasks.

## social/Main.pudu

Chatter: posts, approvals and replies, rendered on the server.

```bash
pudu run examples/social/Main.pudu           # listens on 127.0.0.1:8080
```

Laid out like `fullstack/`, with `Db/` split into one module per table. It
runs without any browser scripts: approving is a form post answered with a
redirect, so the whole example can be driven with `curl`. `Db/Schema.pudu`
holds two numbered migrations. An approval is a row with a unique
(post, reader) pair rather than a counter, so two racing requests cannot lose
a like.

## web

### web/Notes.pudu

A persistent SQLite or PostgreSQL service with HTML and JSON routes, typed row
mapping and ordered application stages. See [the web example](web/README.md).

### web/EnterpriseSsr.pudu

A library of building blocks for streamed server rendering, not a program to
run: a document head sized to fit the first TCP round trip, an interactive
island that hydrates when scrolled into view and still works as a plain form,
and security headers. `pudu check examples/web/EnterpriseSsr.pudu` compiles it.

## db

Three programs run against a real database: the driver, the query builder and
row mapper, and joins with grouped reports. Each check is reported by name. See
[the database examples](db/README.md) for the order to run them in, how to
point them at PostgreSQL, and what running them found.

## media/Studio.pudu

A bounded Pudu-native media laboratory. It renders an 8 kHz mono audio graph,
writes the result as a valid PCM WAV in the system temporary directory, aligns
24 generated pictures to the same exact timeline, and presents those pictures
through a real desktop window.

```bash
pudu run examples/media/Studio.pudu
pudu run examples/media/Studio.pudu --config examples/media/studio.json
```

This run shows audio representation, graph rendering, WAV output, exact video
timing, Canvas rendering, and a native window working together. With
`audio.playToDevice` on, as it is by default, it also plays the sound through
the default output device and reports the device's frames, clock, underruns
and interruptions. It does not decode media or test camera or microphone
capture. Each successful run
writes a JSON report of configuration, monotonic durations, observations, and
capability states beside the WAV. The gaps are listed in
`wiki/architecture/DESKTOP-CONFORMANCE.md` rather than implied.

`media/ConfigChecks.pudu` checks the configuration loader's refusals: missing
fields, wrong types, out-of-range sizes, a WAV name that climbs out of the
temporary directory, and an audio buffer too small to be safe. The test suite
runs it.

## raylib

Both need raylib on the loader's path:

```bash
DYLD_LIBRARY_PATH="$(brew --prefix raylib)/lib" pudu run examples/raylib/Window.pudu
DYLD_LIBRARY_PATH="$(brew --prefix raylib)/lib" pudu run examples/raylib/Snake.pudu
```

### raylib/Window.pudu

A window, drawn by a library written elsewhere. It is the shape a real binding
takes, and it is worth reading for the shape rather than for the drawing:

- **The colour is an ordinary record.** `Color` is declared, built, and read the
  ordinary way, and crosses to raylib by value. Nothing about it is special to
  the boundary except the declaration that names it.
- **The raw binding sits in a block of its own**, and every function in it
  requires the `foreign` capability of whoever calls it — because the signatures
  are asserted against raylib and nothing here can check that assertion.
- **The wrapper takes that on once.** `runFor` opens one unsafe region, and a
  caller of `runFor` needs no capability at all. The assumption stops at the
  edge, in the module that made it, rather than spreading to everything that
  draws.

### raylib/Snake.pudu

A whole game rather than a demonstration of one feature. It keeps state across
frames, grows an array, reads input and asks the platform for random numbers.
Each frame makes a few dozen calls across the foreign boundary, so a few
seconds of play is tens of thousands of them. That is the load a real binding
sees, and why a foreign call resolves its symbol once rather than on every call.
