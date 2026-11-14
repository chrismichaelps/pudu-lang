---
type: handoff
status: ACTIVE
aliases: [Lane Collection Delivery]
tags: [handoff, runtime, performance]
---
# Lane Collection Delivery

Issue #726 runs on feature/726-lane-parallel-gc, stacked on feature/668-float-lanes because dev
has no lanes yet. Scope owns the executable's linked RTS options, the collection fixture, gate,
benchmark, CI and gate registration, and their vault pages. Role transition: Runtime Engineer
reproduced and fixed; Tooling/Release registered the gate. Reviews remain pending.

Found while measuring the Ark parallel system schedule: lane work on four workers ran no faster
than on one, while interpreted loops scaled. Forcing results inside workers changed nothing.
Each kernel writes a fresh pinned buffer; under the default large-object limit nearly every
kernel call triggered a stop-the-world collection, which waits for every other thread's
non-allocating kernel loop. Paired runs on 10 cores: limit 16 MB four workers 66-78 ms, 32 MB
49 ms with one worker 107 ms and 159 MB peak, 64 MB 47 ms at 112 ms, 128 MB 50 ms at 117 ms and
286 MB, unlimited default 98-108 ms at 103-110 ms and about 178 MB. 32 MB is linked.

Gate red/green: 203 collections for the 400-call fixture before, 37-39 after, at one and two
capabilities. Serial benchmarks (eval suite and LanesBench, fastest of five) moved -2.9% to
+1.4%; the reference binary was the engine-branch build, so sources differ slightly.

Exact next action: obtain independent implementation, Language Architect and Forensic Guardian
reviews on the draft PR.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Cabal]] · [[Lane Collection Gate]]
