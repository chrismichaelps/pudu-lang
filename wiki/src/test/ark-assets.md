---
type: module
path: "@root/test/ark-assets.mjs"
fidelity: Active
aliases: [Ark Assets Gate]
tags: [module, ark, assets, test]
---

# Ark Assets Gate

## Purpose and interface

Execute [[Ark Texture Fixture]] with exact output against an explicit compiler and checkout
library. Verify formatter stability, a positioned E3001 for a nonnumeric UV argument and source
archive inclusion of the texture module. Remove temporary programs and archives afterwards.
[[Ark Asset Graph Fixture]] also executes with exact output; graph source/fixture formatting and
nested graph-module archive inclusion are mandatory. [[Ark Asset Server Fixture]] runs with exact
output, and every Assets module (Texture, Graph, Import, Server) must be formatted and shipped.
CI and the local gate register this focused check; no full suite is invoked by this script.

[[Ark Stream Fixture]] executes with exact output too; the stream module and fixture are
formatted and shipped, and a text worker budget must fail with a positioned E3001.

## Resolved Grill Log

- **Q:** Consider a working checkout sufficient shipping evidence? **A:** No; inspect the source
  archive so nested asset modules cannot disappear from installed distributions.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Texture Fixture]] · [[Ark Texture Delivery]]
