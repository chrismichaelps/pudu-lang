---
type: handoff
status: IMPLEMENTING
issue: 967
tags: [native, toolchain, cache, performance]
aliases: [Native Build Cache Delivery]
---
# Native Build Cache Delivery

Backend Engineer implements the native output cache in [[Backend Toolchain Cache]] and its consultation in [[Backend Toolchain]]. The cache keys on the generated C, flags, linker inputs, the C compiler's resolved path and version output, the operating system and architecture, and the compiler identity. A hit copies the stored executable beside the output and returns the stored warnings; a miss compiles and stores through a temporary file and rename.

Part two, reachable-only emission, is moot. Lowering is already demand-driven from main, and runtime parts are included by use. The remaining size is reachable code, not unreachable emission.

Acceptance: hit and miss paths, failure fallback to compile, concurrent store safety, count-bounded pruning by modification time, and unchanged generated output.

Exact next action: Validate cache hits and misses, then open the PR to dev.

## Referenced by

[[handoffs/_MOC]] · [[Backend Toolchain Cache]] · [[Backend Toolchain]]
