---
type: module
path: "@root/test-fixtures/ark/UsesArkPlatform.pudu"
fidelity: Active
aliases: [Ark Platform Fixture]
tags: [module, ark, test]
---
# Ark Platform Fixture

Decodes every adapter record kind through [[Ark Input]]'s factory table and skips unknown or
malformed ones; checks press/repeat/release/tap-within-a-frame state, per-frame clearing,
deduplicated bindings, action reads, axes and rebinding; [[Ark Frame Clock]] steps, alpha,
pacing, step-budget drops and a backwards clock; [[Ark Window]] refusals that never reach the
platform and an unknown window. Prints `ark platform: ok`.

Window state: `scale`, `focus`, `minimize` and `fullscreen` records decode and malformed ones
(zero scale, non-boolean flags, wrong field counts) are skipped; losing focus releases held keys
and buttons; `pixels` rounds fractional scales up; `observe` sets content size, scale and flags,
keeps frames at content size unless sharp, refuses a degenerate resize, re-applies density for a
sharp rescale (reaching the platform), touches nothing for an unchanged scale and refuses an
out-of-range density; `configure` maps inverted and negative limits, a half aspect and valid
settings on a missing window to their typed refusals.

## Referenced by

[[Ark Platform Gate]]
