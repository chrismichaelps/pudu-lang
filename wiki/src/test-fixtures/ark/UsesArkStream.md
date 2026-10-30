---
type: module
path: "@root/test-fixtures/ark/UsesArkStream.pudu"
fidelity: Active
aliases: [Ark Stream Fixture]
tags: [module, ark, test, assets]
---
# Ark Stream Fixture

Streams assets from a memory mount through [[Ark Asset Stream]] and checks that the payloads
equal a synchronous [[Ark Asset Server]] `open` of the same sources, including a material that
depends on a texture; that no pump commits more than its budget; that with one worker the higher
priority commits first; that a cancelled request never loads; that a duplicate request is ignored
and a request for a loaded asset is dropped; that read and import failures arrive per asset; that a
request whose dependency nobody requested is reported blocked and keeps waiting; and that a budget
below one is refused. Prints `ark stream: ok`.

## Referenced by

[[Ark Assets Gate]] · [[Ark Asset Stream]]
