---
type: handoff
status: IN_REVIEW
issue: 660
aliases: [Ark Matrix Delivery]
tags: [handoff, ark, math]
---
# Ark Matrix Delivery

Fresh feature/660-ark-matrix starts from fetched development c13dd93e. Independently reviewed
foundation #652 and graph #658 branches are merged locally as explicit prerequisites while
their hosted checks run. Documentation-only merge conflicts preserve both navigation/ledger
entries. This slice's final PR remains targeted at development and must exclude already
integrated prerequisites before review-size acceptance. No unrelated work or build files removed.

Role transitions: Language Architect → Library Engineer → Test Engineer → independent Language
Architect and Forensic Guardian. Library Engineer owns Math.pudu's additive Vec4 and new
Math/Matrix.pudu. Release Engineer owns the nested data-file glob. Test Engineer owns the
matrix fixture/gate. Architect owns resolved mirrors, convention page and navigation. Mirrors
exist before implementation. Existing Vec3 semantics remain unchanged.

Contract: [[Ark Math Conventions]] explicitly defines binary64 column-vector algebra and
checked homogeneous projection. No arrays in matrix arithmetic, no native throughput/layout
claim and no engine C11 emission. Focused checks only; repair exposed Pudu defects at their source.

Evidence: focused check/run/format, wrong-dimension/precision E3001 at the call line and nested
source-archive inclusion pass. Affected optimized executable build passes with `-Werror`.
Integrated layer scan reports 219 source modules, two engine modules and zero findings.
Independent Language Architect/implementation review passes, with the reviewer independently
running the matrix gate and layer scan. CI and local gates now register the focused regression;
the ledger distinguishes completed algebra from open inverses/camera and other Math work.
No full gates run. A separate audit reproduces Std.Math.Float.sqrt exponent-range errors;
repair is required before continuing math features, without changing this matrix convention.

Exact next action: integrate the reviewed prerequisite PRs and publish this bounded matrix slice,
then fix full-range standard-library square root with focused regressions before further Ark work.

## Referenced by

[[handoffs/_MOC]] · [[Ark Matrix]] · [[Ark Math Conventions]]
