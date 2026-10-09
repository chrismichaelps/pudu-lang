---
type: module
path: "@root/test/Pudu/DocSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, documentation]
aliases: [Documentation Spec]
---

# Documentation Spec

## Purpose and interface

Exercises the documentation index, query parser, ranking, JSON encoding, and standalone HTML site
through checked Pudu source fixtures.

## Governance and algorithm

The documentation attachment fixture distinguishes direct comments, ordinary comments, exported
declarations, block comments, and trait-member inheritance. It proves an undocumented
implementation member receives the matching trait member's explanation, a direct implementation
comment overrides that fallback, and a same-named member from another trait cannot leak across the
trait boundary.

## Negative logic

- No assertion depends only on encoded text when the structured `DocEntry` can be inspected.
- No inheritance fixture omits the competing same-named trait; trait identity must be tested, not
  assumed.
- No direct implementation comment may be replaced by inherited text.

## Grill Log

- **Q:** Is one successful inheritance assertion sufficient? **A:** No. _Rationale:_ lookup by
  member name alone would pass it while attaching unrelated documentation in real modules.
  _Rejected:_ a single trait and implementation fixture.
- **Q:** May inherited text overwrite implementation-specific guidance? **A:** No. _Rationale:_ the
  implementation comment is closer and can describe behavior unique to that type. _Rejected:_
  unconditional replacement.

Resolved Grill Log: the fixture checks the success, override, and cross-trait isolation paths.

## Referenced by

[[Doc Index]] · [[Doc Search]] · [[Doc Json]] · [[Doc Site]]

## Derive index contract (#458)

The checked program graph must retain public Record and Sum headers, private strategies, trait applications, declaration and member comment boundaries, distinct spans and full rendered headers. Strategies carry no callable scheme and are excluded from shape search and binding completions; hover and outline inspection retain them.

Resolved Grill Log: assertions exercise graph compilation, so testing an isolated index cannot conceal earlier elaboration loss. [[Derive Index Output Gate]] independently checks actual command output.
