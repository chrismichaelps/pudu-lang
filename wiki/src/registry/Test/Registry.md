---
type: module
path: "@root/registry/src/Test/Registry.pudu"
fidelity: Active
tags: [registry, tests]
aliases: [registry Test Registry]
---
# Registry Test Registry

The registry suite against a fake GitHub: manifest rules, commit archives (top directory, dot paths, `deps/`, links, traversal), canonical packing, tokens and their cache, release rules (tag, commit, publisher, immutability, major-line order, version match, push permission, missing token, invisible repository), yanking, private visibility through the routes, profiles, `config`, `whoami`, and search.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Test over a socket? **A:** Through `Route.dispatch` with a fake `GitHub`; `test/package-registry.py` covers the socket and a stand-in GitHub.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
