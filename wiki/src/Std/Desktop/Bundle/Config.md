---
type: module
path: "@root/lib/Std/Desktop/Bundle/Config.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, packaging]
aliases: [Std Desktop Bundle Config]
---

# Std Desktop Bundle Config

## Purpose and interface

The declarative bundle configuration read from `pudu-desktop.toml`: `Config` with its `[app]`,
`[build]`, `[bundle]`, `[bundle.macos]`, `[bundle.linux]`, `[bundle.windows]` and `[updater]`
sections; `parse` and `load` read it; `packageName` derives the lower-case package name;
`Inputs` carries what every format consumes (the built executable, the packed frontend, an icon);
`BundleError`, `tool`, `writeFile` and `xmlEscaped` are shared by the formats.

## Semantics

- Required: `app.name`, `app.identifier` (reverse-DNS, at least two dot-separated labels of
  letters, digits and hyphens), and `app.version` (semantic version). Everything else has a default:
  entry `src/Main.pudu`, frontend `frontend`, output `dist`, targets for the building platform,
  macOS 12.0, Linux section `utils`.
- An unknown target name or update channel is refused when the file is read, not when a format runs,
  so a typo cannot silently skip a package.
- Signing settings are only names and paths; secrets never live in the file. The updater's secret key
  comes from `PUDU_DESKTOP_SIGNING_KEY` at bundle time.

- `tool` refuses with `ToolMissing(format, program)` when a needed program is not installed and with
  `ToolFailed` carrying its output when it exits non-zero.

## Grill Log

- **Q:** Why validate the identifier strictly? **A:** It becomes the macOS bundle identifier, the
  data-store namespace and part of package names; an invalid one fails late, on another platform, or
  at notarization.

## Dependencies and consumers

Uses [[Std Toml]], [[Std Io]] and [[Std Semver]]. Consumed by every [[Std Desktop Bundle]] format and
[[Std Desktop Cli]].

## Referenced by

[[src/Std/_MOC]]
