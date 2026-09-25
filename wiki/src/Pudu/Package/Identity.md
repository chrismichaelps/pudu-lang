---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Identity.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, identity]
aliases: [Package Identity]
---

# Package Identity

## Purpose and interface

`@handle/name` and local names (`PackageId`), their grammar (lowercase letters, digits, single hyphens, up to 39 characters; `std`, `core`, `pudu`, `admin` reserved as handles), the default module root (`json-schema` → `JsonSchema`), root validation (`Std` and `Core` refused), the `deps/` directory for each identity, and `parseInstallSpec` for `pudu install` arguments: `@h/n[@version]`, paths, and git URLs (`git+…`, `…​.git`, `#rev`).

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Prefix modules with the handle? **A:** No; a package owns a root. _Rationale:_ imports would change when a project changes hands. _Rejected:_ `Alice.JsonSchema.*`.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
