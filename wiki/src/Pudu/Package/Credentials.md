---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Credentials.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, security, tokens]
aliases: [Package Credentials]
---

# Package Credentials

## Purpose and interface

Tokens per registry URL in `$PUDU_HOME/credentials.toml` (`puduHome` defaults to `~/.pudu`), written through a staging file set to mode 0600 before the token is written. `PUDU_TOKEN` takes precedence for every registry. `loadCredential`, `saveCredential`, `removeCredential`.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Store tokens in the manifest or lock? **A:** Never. _Rationale:_ both are committed. _Rejected:_ project-local credentials.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs` and `test/package-registry.py`.
