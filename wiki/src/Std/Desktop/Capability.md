---
type: module
path: "@root/lib/Std/Desktop/Capability.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, security]
aliases: [Std Desktop Capability]
---

# Std Desktop Capability

## Purpose and interface

The least-privilege model for WebView calls. A `Capability` names the views (by label) and origins
it applies to, the commands it `allow`s (each with an optional argument `Scope`), and the command
patterns it `deny`s. `combine` validates a set; `decide(grants, label, origin, command)` answers
`Unrestricted`, `Scoped(scopes)` or `Refused(reason)`; `permits(decision, value)` checks one scoped
argument. `parse` and `load` read capability files; `expand` substitutes `$NAME` variables in scopes;
`originOf` reduces a page URL to its origin.

## Semantics

- Nothing is granted by default: a command no applicable capability allows is refused, and the
  reason names the command, the view and the origin.
- A capability applies when its `views` hold the label or `*`, and one of its `origins` patterns
  matches the origin. Origins and commands match with [[Std Glob]].
- Any applicable deny wins over every allow.
- Several applicable allows for one command merge: one unscoped allow makes the call
  `Unrestricted`; otherwise every limit is kept and a value is permitted when some limit allows it
  and no limit denies it.
- `combine` refuses two capabilities with the same identifier, so a file cannot silently replace
  another.
- `originOf` lower-cases the scheme and host and keeps an explicit port; a URL with no host has the
  origin `null`, which no default capability names.

## Grill Log

- **Q:** Why must scopes be checked by the command rather than by the dispatcher? **A:** Only the
  command knows which argument is a path, a URL or an identifier; the dispatcher hands it the
  decision through `Ipc.Call` and the command calls `permits` on the value it is about to use.
- **Q:** Why glob rather than regular expressions for origins? **A:** A capability file is written by
  a person, and a `.` that matches any character in an origin pattern is a security hole a glob
  cannot have.

## Dependencies and consumers

Uses [[Std Glob]], [[Std Toml]], [[Std Url]] and [[Std Io]]. Consumed by [[Std Desktop Ipc]],
[[Std Desktop Plugin]] and [[Std Desktop App]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
