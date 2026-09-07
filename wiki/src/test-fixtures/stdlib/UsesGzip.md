---
type: module
path: "@root/test-fixtures/stdlib/UsesGzip.pudu"
fidelity: Active
---
# UsesGzip

## Purpose and interface

Existing codec fixture main. Preserve the established cases while migrating compressed corruption
to the zlib CodecFailure result and replacing obsolete stored-block and passthrough commentary.

## Grill Log

Resolved: real DEFLATE corruption can fail structural decoding before a checksum is reached; do
not demand a checksum-only error for an arbitrary modified compressed byte. No fixture is executed.

## Referenced by

[[Std Compress Gzip]]
