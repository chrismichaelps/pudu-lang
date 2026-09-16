---
type: script
path: "@root/website/scripts/normalize-catalog.mjs"
fidelity: Active
tags: [website, generated, documentation]
---
# Website catalogue normalizer

Filters documentation through `pudu api --json`, deduplicates declarations reached through more
than one documentation root, sorts their stable API identity, and adds the website index and
language versions. The projection keeps only fields the server reads: module, kind, name,
signature, and documentation. Compiler type trees and source spans stay in compiler output rather
than increasing every website process start. It uses only the Node standard library.

Resolved Grill Log: retain the first complete public record for each module/kind/name/signature
identity, omit compiler-only metadata, and fail rather than emit a catalogue when the compiler JSON
shape is absent.
