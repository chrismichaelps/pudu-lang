---
type: module
path: "@root/registry/src/Domain/Name.pudu"
fidelity: Active
tags: [registry, packages, identity]
aliases: [registry Domain Name]
---
# Registry Domain Name

Package names: `validSegment` (lowercase ASCII letters, digits, single hyphens, 1–39 characters), `reservedHandle` (`std`, `core`, `pudu`, `admin`, `api`, `login`, `packages`), `parse`/`render` of `@handle/name`, `fromRoute` for the two route segments, `defaultRoot` (PascalCase of the name), `validRoot` (one capitalised segment, never `Std` or `Core`), and `closeTo` (at most one edit apart).

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Reserve route words as handles? **A:** Yes: `api`, `login`, `packages`. _Rationale:_ `/@h` pages share the site's address space. _Rejected:_ reserving only the compiler's roots.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
