---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 264
tags: [handoff, stdlib, html, safety, ssr]
aliases: [2026-09-20-checked-html-destinations]
---

# Checked HTML Destinations Handoff

## Objective

Resolve issue #264 with checked destination setters across the persistent fluent builder and its
generic checked attribute path, while retaining explicit compatibility and trusted escape hatches.

## Ownership and role transitions

1. **Language Architect:** [[Std Html]] and [[Std Html Build]] settle additive method names,
   compatibility, destination-bearing attribute names, and the trusted bypass boundary.
2. **Runtime Engineer:** owns `Std/Html.pudu`, `Std/Html/Build.pudu`, and their mirrors.
3. **Test Engineer:** owns `UsesHtmlDestinationBuild.pudu` and its explicit result in
   `ServiceSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff after gates.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required. No separate review agent is used.

## Contract

- Existing `at`, `href`, `src`, and `action` strings remain unchanged as unchecked compatibility
  entry points.
- `hrefTo`, `srcFrom`, and `actionTo` accept only `Html.Destination`; checked string conveniences
  return `Html.Unsafe` on refusal.
- `atChecked` delegates to `Html.attribute`. Case-insensitive `href`, `src`, and `action` values pass
  through `Html.destination`, so a generic checked call cannot bypass destination validation.
- Case-insensitive `on*` names and controls remain refused. Rendering continues to omit handlers
  supplied through raw or legacy paths as defense in depth.
- `Html.trustedDestination` remains the explicit, review-visible way to opt out of scheme checking.
- Accepted builder output is byte-identical through ordinary rendering and a prepared SSR plan.

## Measurement boundary

This change is a safety migration and makes no runtime speedup, allocation reduction, or complexity
claim. Checked setters add validation before persistent attribute append; rendering remains delegated
to the same iterative `Std.Html` implementation.

## Exact next action

Run the complete repository gates, reconcile generated documentation, then commit directly to
`dev`, post the commit on issue #264, close it, and continue to issue #265.

## Completion evidence

- `UsesHtmlDestinationBuild.pudu` checks without diagnostics and returns all 16 focused assertions.
- The warning-free optimized build, complete optimized test suite, formatter, diagnostic-code,
  release-plan, API-coverage, residency, scaffold, lint, LSP session/robustness, and documentation-site
  gates pass.
- `git diff --check` passes, both implementation modules remain below 500 lines, and
  source/mirror/MOC/changelog parity is complete.

## Referenced by

[[handoffs/_MOC]] · [[Std Html]] · [[Std Html Build]] · [[src/Std/_MOC]]
