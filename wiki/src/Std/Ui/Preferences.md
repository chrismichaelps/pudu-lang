---
type: module
path: "@root/lib/Std/Ui/Preferences.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, settings, persistence]
aliases: [Std Ui Preferences]
---

# Std Ui Preferences

## Purpose and interface

An application's saved settings: typed values by key, stored as one JSON object in the platform's
per-user settings directory and replaced atomically.

Exports: `type Preferences`, `type PreferencesError`, `empty`, `pathFor`, `load`, `loadFrom`, `save`,
`saveTo`, `toJson`, `text`, `whole`, `flag`, `setText`, `setWhole`, `setFlag`, `remove`, `keys`,
`explain`.

## Semantics

- Location: `%APPDATA%` when set; `~/Library/Application Support` when present; otherwise
  `$XDG_CONFIG_HOME` or `~/.config`; then `<app>/preferences.json`. An application name containing a
  path separator, a colon, or a leading dot is refused, so it cannot write outside its directory.
- Reads fall back to the caller's default when a key is absent or holds another type, so a settings
  file written by an older version never breaks a newer one.
- Saving creates missing directories and replaces the file in one step through
  `Std.Fs.writeTextAtomically`; a crash leaves the old settings or the new ones, never half of each.
- Absent settings load as empty; a file that is not a JSON object is `Malformed`.

## Grill Log

- **Q:** Bind settings to view fields that save themselves? **A:** No. _Rationale:_ a write hidden
  in a view is disk I/O on every keystroke and a second source of truth; settings are state, saved
  when the program decides. _Rejected:_ self-persisting bindings.
- **Q:** One file or one per key? **A:** One object: a single atomic replace keeps related settings
  consistent.

## Dependencies and consumers

- Depends on [[Std Json]], `Std.Env`, `Std.Fs`.
- Consumed by desktop applications for appearance, window, and feature settings.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
