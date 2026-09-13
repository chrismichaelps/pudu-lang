# Examples

Programs that show what the language does, run by hand rather than by CI.

A gate has to run everywhere. These do not: `raylib/Window.pudu` opens a window,
which needs a display, and a check that cannot run on a headless runner is not
one this repository can rely on. What runs in CI instead is
`test-fixtures/integration/UsesRaylib.pudu`, which reaches the same installed
library through the same boundary without asking for a screen.

So these are here to be read and to be run once, not to be trusted as proof.
The formatter still checks them, because an example that does not compile is
worse than no example.

## media/Studio.pudu

A bounded Pudu-native media laboratory. It renders an 8 kHz mono audio graph,
writes the result as a valid PCM WAV in the system temporary directory, aligns
24 generated pictures to the same exact timeline, and presents those pictures
through a real desktop window.

```bash
pudu run examples/media/Studio.pudu
pudu run examples/media/Studio.pudu --config examples/media/studio.json
```

This run proves audio representation, graph rendering, WAV delivery, exact
video timing, Canvas rendering, and native window presentation together. It
does not play through a speaker, decode media, synchronize to a device clock,
or test camera/microphone capture. Each successful run writes a JSON report of
configuration, monotonic durations, observations, and capability states beside
the WAV in the system temporary directory. Those gaps remain explicit in
`wiki/architecture/DESKTOP-CONFORMANCE.md` rather than implied capabilities.

## raylib/Window.pudu

A window, drawn by a library written elsewhere.

```bash
DYLD_LIBRARY_PATH="$(brew --prefix raylib)/lib" pudu run examples/raylib/Window.pudu
```

It is the shape a real binding takes, and it is worth reading for the shape
rather than for the drawing:

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

## web/Notes.pudu

A persistent SQLite or PostgreSQL service with HTML and JSON routes, typed row mapping and
ordered application stages. See [the web example](web/README.md).
