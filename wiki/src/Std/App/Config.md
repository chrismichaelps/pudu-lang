---
type: module
path: "@root/lib/Std/App/Config.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, configuration]
aliases: [Std App Config]
---
# Std App Config
## Purpose
Settle where a setting comes from when four places could have supplied it.
## Interface
`discover` — declared defaults, a named file, the machine, and this invocation, with the profile
found wherever it was given. One call, and it is what most programs want.

Beneath it, a configuration built from layers, and the layers themselves: declared defaults, a document read as
[[Std Toml]], the environment, and arguments. Reading a setting as text, a whole number, a truth, a
fractional number, or a list, each answering a `Result` that says what was expected and what was
found. Reading with a fallback. Requiring a setting, which fails when it is absent. Selecting a
profile, and asking which one is active. Asking which layer an answer came from.
## Governance and algorithm
Layers are consulted last to first, so the later wins: a default is overridden by a file, a file by
the environment, and the environment by an argument. That order is fixed rather than configurable,
because a program whose override order is itself configurable has moved the question rather than
answered it.

There are four layers and there will not be more. The established framework in this space has
fifteen, and the consequence is that answering "where did this value come from" requires consulting
a table rather than looking. Four is the number that covers the actual cases: what the program
declares, what the deployment writes down, what the machine sets, and what this invocation
overrides. A source outside those is a program reading a file and adding a layer, which it can do.

A default is a layer like any other, so a declared default is readable, reportable, and traceable to
its source exactly as a value from a file is. It is not a fallback applied somewhere else after the
lookup failed — that arrangement is what makes a declared default invisible to anything that asks
the configuration what it holds.

One key has one spelling. A key is dotted, lowercase, and matched exactly; the environment
transformation is the single exception and it is a transformation rather than an alternative. Where
several spellings of a key are all accepted, a mistyped key silently becomes a different key that
also works, and a value that should have collided quietly does not.

A setting is typed where it is read, not where it is declared. The name of a setting says nothing
about its type, so a port read as a whole number and the same port read as text are both legitimate
and neither is a cast — the read states what it expects and reports what it found when the text
cannot be that. A failure names the key, the layer, and the text, because a program refusing to
start over a setting should say which one and where it was written.

An environment variable is matched by transforming the dotted key rather than by keeping a table
of both spellings: `server.port` is `SERVER_PORT`. A table would be a second place to forget.

A profile selects a section of the document layer and nothing else. The environment and arguments
are not profiled, because they are already specific to the machine the program is running on.
## Grill Log
- **Q:** Let the layer order be configured? **A:** No. _Rationale:_ the order in which overrides
  apply is the one thing that must not itself be overridable, or reasoning about a value requires
  first finding out how values are found. _Rejected:_ a caller-supplied precedence list.
- **Q:** Bind the whole configuration into a record up front? **A:** No. _Rationale:_ that requires
  either reflection or a hand-written binder per record, and it forces every setting to be valid
  before any of them can be read — so a program is refused over a setting it never uses.
  _Rejected:_ whole-document binding.
- **Q:** Keep a table mapping keys to environment variable names? **A:** No. _Rationale:_ a
  transformation is one rule; a table is a second place for the two spellings to disagree.
  _Rejected:_ an explicit name table.
- **Q:** Profile the environment layer too? **A:** No. _Rationale:_ the environment is already the
  machine's own answer; profiling it would let a machine's setting be ignored because of a value
  written in a file. _Rejected:_ profile-scoped environment lookups.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Toml]] · [[Std Env]] · [[ADR-0016 An Application Is a Value]]
