---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/Progress.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, packages, progress]
aliases: [Pudu CLI Progress]
---

# Pudu CLI Progress

## Purpose and interface

`startDisplay verbosity` answers a `Display` whose `displayProgress` counts events into a `Tally`. For an interactive stderr at normal verbosity a ticker redraws one live line every 80 ms — spinner, phase (`Resolving` with fetched and cached counts, then `Installing n/total` with copied and up-to-date counts), what is in flight, and elapsed time. `stopDisplay` erases the line and answers the tally for the lasting report. `Verbose` prints each event as a timed line; `Quiet` shows nothing. `painter` colours added, removed, changed, dim, and strong text only for a terminal stdout without `NO_COLOR`. `milliseconds` renders a duration as `412ms` or `1.3s`.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Live line on stdout? **A:** On stderr. _Rationale:_ stdout keeps only the lasting summary, so a redirected report is clean. _Rejected:_ interleaving redraws with the report.
- **Q:** Redraw when stderr is not a terminal? **A:** No. _Rationale:_ carriage returns fill a CI log. _Rejected:_ always animating.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
