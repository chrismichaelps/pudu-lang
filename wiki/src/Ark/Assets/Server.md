---
type: module
path: "@root/lib/Ark/Assets/Server.pudu"
fidelity: Active
aliases: [Ark Asset Server]
tags: [module, ark, assets, reload]
---

# Ark Asset Server

## Purpose and interface

`Source` declares an asset ID, a virtual path (`mount:/relative`), an importer kind and the
dependency IDs whose imported payloads the importer receives in declared order. Importer kinds
and payloads belong to [[Ark Asset Import]]; the server checks kinds at declaration and runs them
during staging.

`open(vfs, sources) -> Result[Server, Error]` compiles [[Ark Asset Dependencies]], reads and
imports every asset dependency-first and issues one [[Ark Handle]] per asset. `add` declares and
loads one more asset whose dependencies are loaded. `handle`,
`payload`, `revision` and `ids` read published state; `payload` refuses stale handles.

`changed(server)` re-reads every source and reports the IDs whose bytes differ from the bytes
their published revision imported. `reload(server, ids)` stages the union of `Graph.affected`
closures in dependency-first order. An asset is re-imported only when its own bytes changed or
a dependency published a new revision during the same reload; otherwise it keeps its revision
and payload. Every staged import completes before a new server value is returned, so any read or
import failure leaves the caller's published server unchanged. The result names exactly the IDs
whose revisions advanced.

`refresh` composes both into one staged publication. `unload(server, id)` refuses while a loaded
dependent remains, releases the handle (making every copy stale) and recompiles the remaining
declarations; a re-added asset may reuse the slot under a new generation.

## Invariants

- Published state is a value: a failed stage cannot leave a partially published server.
- A revision advances only when the importer ran; unchanged bytes with unchanged dependency
  revisions are no-ops, including for dependents of a changed asset whose bytes were identical.
- Source bytes of the published revision are retained for exact change detection; a payload
  produced by `bytes` shares that storage rather than copying it.
- Handles are store-local generational indices, not global or unforgeable identities.
- Directory reads observe the host filesystem at read time; atomicity covers published server
  state, not a filesystem-wide snapshot.

## Resolved Grill Log

- **Q:** Detect changes with a 64-bit digest? **A:** No; a collision would silently skip a
  reload. Retain the exact bytes and compare them; memory cost equals one source copy.
- **Q:** Publish each asset as soon as it re-imports? **A:** No; a later failure would expose a
  dependent built against a half-updated set. Stage the whole closure, then publish once.
- **Q:** Re-import every dependent of a changed source? **A:** No; a dependent re-imports only
  when a dependency's revision advanced in this reload, so byte-identical rewrites cost one read.
- **Q:** Keep importers inside the server? **A:** No; payload formats evolve independently of
  revision bookkeeping, so [[Ark Asset Import]] owns them and the server only stages.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Asset Server Fixture]] · [[Ark Assets Gate]] · [[Ark Asset Server Delivery]]
