---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/Init.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, project, initialization]
aliases: [Pudu CLI Init]
---

# Pudu CLI Init

## Purpose and interface

Create a canonical Pudu project without overwriting user content. `createProject` returns either a
typed `InitError` or the canonical initialized root; `renderInitError` provides the CLI message.
`packageNameFrom` normalizes a directory name to the package-name grammar for focused testing and
other project tooling. Letters are lowercased, every character outside ASCII letters and digits
becomes a separator, and a run of separators becomes one; only separators collapse, so a doubled
letter stays part of the name (`hello`, `book-keeper`, `app2`).

`createProjectWith` accepts an optional explicit package identity and a library mode. An explicit
identity is parsed by [[Package Identity]], so `@owner/repo` follows the same rules as installation
and publication. The directory-derived local name is checked against that grammar too. Library mode
derives its module root through `defaultRoot` and `validRoot`, writes `src/<Root>.pudu` and a test
that imports it, and includes `root` in the manifest. Application mode retains the existing layered
entry point and test. Both modes write the package schema's name, version, language, source,
description, license, keywords, and an empty dependency table; empty descriptive fields invite the author to
fill in real metadata. Only a registered identity can be published, and it must match the GitHub
repository. `createProject` remains the default application entry point for compatibility.

## Governance and algorithm

Initialization resolves and validates the target before writing managed content. An explicit target
that is itself a symbolic link is refused. `src` and `test` must be real directories when present;
managed files must be regular files and not links. An existing manifest is always a refusal.
Existing source, test, README, and ignore files are preserved. The generated project itself contains
only Pudu source: `Main` is the composition root, `App.Greeting` is the application layer, and
`Domain.Greeting` is the pure domain layer. Dependencies point inward only. The test root exercises
both public layers through the manifest's implicit project source root.
The README includes the native lint command, and the generated graph is clean under it without an
initial suppression list.

A private directory lock serializes Pudu initializers. Lock acquisition is the atomic filesystem
operation; a competing creator maps the operating system's already-exists result to the stable
`InitializationInProgress` refusal instead of leaking a host exception. Missing content is written to staging files
inside that lock and renamed into place; `pudu.toml` is renamed last and is therefore the completion
marker. An ordinary caught failure removes the lock. If a process or machine dies, the remaining
lock is an explicit recoverable refusal instead of permission to mix two partial initializations.

The package name lowercases ASCII letters, keeps digits, turns each run of other characters into one
hyphen, and removes edge hyphens. Empty results and the reserved `std` and `core` roots are refused.
The README heading retains the human directory name; the manifest gets the normalized identity.

## Grill Log

- **Q:** Overwrite an existing entry with the current template? **A:** No. _Rationale:_ scaffolding
  is not authority to replace program source. _Accepted:_ preserve regular managed files and create
  only missing ones. _Rejected:_ force-by-default; refusing every non-empty directory.
- **Q:** Write the manifest first? **A:** No. _Rationale:_ project discovery treats it as the root
  marker, so it must not advertise a complete project while source or tests are still absent.
  _Accepted:_ stage content and commit the manifest last. _Rejected:_ sequential direct writes.
- **Q:** Follow a symbolic-link target? **A:** No. _Rationale:_ the command would report one path
  while modifying another tree. _Rejected:_ canonicalizing through the final target silently.
- **Q:** Put arbitrary directory text in `package.name` because TOML can escape it? **A:** No.
  _Rationale:_ TOML validity is weaker than Pudu's package identity grammar. _Accepted:_ stable
  normalization with typed refusal when no valid identity remains. _Rejected:_ invalid package
  names; locale-dependent case folding.
- **Q:** Generate one source file with every responsibility? **A:** No. _Rationale:_ it teaches a
  structure that stops scaling as soon as IO, orchestration, and domain rules grow. _Accepted:_ a
  three-node acyclic Pudu graph with the effect at the composition root. _Rejected:_ Haskell files
  or Haskell knowledge in the generated project; a framework-heavy starter.

- **Q:** Should an application starter pretend its `App` and `Domain` modules belong to a
  distributable root? **A:** No. An explicit library mode writes a module under the canonical root;
  the application starter keeps its runnable composition graph. _Rationale:_ installed packages
  promise a module root and an application entry point serves a different job. _Rejected:_ a root
  field that names no generated module.

Resolved Grill Log: initialization is additive, typed, serialized, staged, and uses the package
identity grammar rather than only the serialization grammar. Library source lives under its owned
root without a local-only dependency.

## Referenced by

[[Pudu CLI]] · [[Pudu CLI Init Spec]] · [[src/Pudu/_MOC]] · [[architecture/PACKAGES]]
