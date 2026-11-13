---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Audio.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Audio]
---

# Native Host Audio

Select the packaged AudioToolbox sources and emit host outcomes for playback
and streams, including snapshot counters and device status.

## Resolved Grill Log

Use the adapter's public ABI. The run gate serializes stream token lookup
and consumption. Stream close detaches the token before invoking the
adapter. Teardown drains outstanding streams. Keep validation and refusal
ordering identical to the interpreter on each target.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Host Runtime]] · [[Native Audio Adapter Delivery]]

## Native stop observation (#857)

Resolved Grill Log: playback also accepts a stop predicate. The adapter
polls it on the playback thread beside the existing cancellation token.
Native playback releases the run gate during the call and reacquires it
before returning the outcome.
