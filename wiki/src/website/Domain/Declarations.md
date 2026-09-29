---
type: module
path: "@root/website/src/Domain/Declarations.pudu"
fidelity: Active
tags: [website, domain, api, packages]
aliases: [website Domain Declarations]
---
# Website Domain Declarations

Reads the public declarations of one Pudu source file from its text, for a release whose API
reference must be built without the compiler. `read` takes the `module` line, then every
top-level `export fn`, `export async fn`, `export type`, `export trait`, and `export const`, each
as a [[website Domain Entry]] of that module:

- **Signature:** a function's header as declared after its name — type parameters, parameters,
  and result, joined across lines while brackets are open and cut before the body's `{`; a
  constant's declared type; nothing for a type or trait.
- **Documentation:** the `///` lines directly above, as paragraphs (consecutive lines joined, a
  blank line ends one), stopping at the first heading or code fence so examples stay out of the
  summary. A one-line `/** @Name — intent */` anchor contributes its intent. Any other line
  between documentation and declaration discards the documentation.
- Text without a `module` line answers `None`; a module without exports answers no entries.

The module is pure: no I/O, no HTTP, no HTML.

## Grill Log

- **Q:** Why read sources instead of running the compiler in the function? **A:** The API reference
  must appear as soon as a package is listed, whatever tool released it. Reading text is bounded
  and predictable on a cold function, needs nothing beyond the files the Source tab already reads,
  and cannot fail on a package the function's compiler version would reject. _Rejected:_ running
  `pudu doc` and `pudu api` per request, which costs seconds of compilation and a writable tree.
- **Q:** Why show signatures as declared rather than as the compiler renders them? **A:** The
  declared header is what the author wrote and reads correctly on its own; the compiler's rendering
  still takes precedence whenever a release carries its catalogue. _Rejected:_ re-deriving types
  from text, which would guess where the compiler knows.

## Referenced by

[[website Service LiveFiles]] · [[website declarations suite]] · [[website/_MOC]]
