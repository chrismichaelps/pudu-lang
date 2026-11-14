---
type: architecture
aliases: [Ark Water Validation]
tags: [architecture, ark, testing, water]
---
# Ark Water Validation

## Current model and first gate

[[Wave Tank Demo]] advances a fixed 56 by 56 grid with reflecting neighbour
indices: next = h + d (h - previous) + q L h, with d = 0.996 and q = 0.3.
It clips displacement and adds seeded drops. This is a visual height-field wave
demo; it does not implement water depth, bulk flow, wet/dry fronts or volume transport.

The first [[Ark Water Gate]] checks the actual production update without rendering:
zero and constant equilibria, analytic discrete reflecting-grid modes, linear
superposition and mean-displacement preservation from zero-velocity initial data.
Keep amplitudes well below clipping and verify every sample is finite. Disable
only scheduled drops through the input step counter, never by rewriting the solver.

For N cells, the reflecting-grid mode is cos(pi p (i+1/2)/N) in each axis.
Its Laplacian eigenvalue is -4 sin²(pi p/(2N)) -4 sin²(pi r/(2N)). The independent
host oracle solves a[n+1] = (1+d+q lambda) a[n] - d a[n-1], with a[-1] = a[0].
Compare full lane values against that mode, not merely a bounded final height.
Tests prove the implemented discrete recurrence, not shallow/deep-water accuracy.

## Later simulation tracks

- Depth-aware waves: measured phase/group velocity across wavelength and depth,
  dispersion reference curves and spatial/time refinement at fixed physical inputs.
- Bulk water: lake at rest over bathymetry, dam break, nonnegative depth, wet/dry
  shorelines, mass balance and obstacle/boat interactions. Requires a suitable solver.
- Free surfaces: moving-container sloshing, buoyancy feedback, breaking waves,
  foam/spray and surface-tension cases. State each representation's capabilities.
- Water optics and sensors: reflection/refraction, attenuation, underwater camera
  and acoustic observations with their own reference data and rendering checks.
- Workflow/performance: repeatable parameter changes, deterministic seeds,
  solver/mesh/render timing separately, memory and resolution scaling per backend.

Visual snapshots complement numerical evidence. Do not infer correctness from a
photoreal frame, clipping, a surrogate inference result or a timing average.

## Resolved Grill Log

A test adapter may rename only the demo entry point and append conformance code.
It consumes the production source verbatim otherwise, retains a source digest,
and fails if the expected entry point or coefficient declarations change.
No copied wave kernel, GPU installation, large model or external assets are needed.
Run both evaluators with cache disabled, cold and warm; verify warm product reuse.
Use bounded small-amplitude runs with explicit error tolerances and no FPS claim.
Separate forcing from unforced balance: added drops do not satisfy a closed-system
mass test. New solver features require their own ready issues and validated contracts.

## Referenced by

[[Ark Engine]] · [[Wave Tank Demo]] · [[Ark Water Gate]] · [[architecture/_MOC]] · [[Water Validation Delivery]]
