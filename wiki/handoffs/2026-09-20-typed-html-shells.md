---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 260
tags: [handoff, stdlib, html, ssr, shell, performance]
aliases: [2026-09-20-typed-html-shells]
---

# Typed HTML Shell Handoff

## Objective

Resolve issue #260 with reusable typed HTML shells containing nested complete-child slots, compiled
iteratively into the existing prepared-plan contract without adding string interpolation, a template
parser, dynamic attribute holes, or a second HTML serializer.

## Ownership and role transitions

1. **Language Architect:** [[Std Html SSR]], [[Std Html Compose]], and [[Std Html Build]] settle the
   structural shell model, child-only slot boundary, builder separation, and compatibility contract.
2. **Runtime Engineer:** owns `Std/Html/Ssr.pudu`, `Std/Html/Compose.pudu`, and their mirrors.
3. **Test Engineer:** owns `UsesHtmlServer.pudu` and its explicit result in `ProtocolSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff after gates.

The repository owner directed this delivery to avoid separate review-agent execution. These roles
describe the completed engineering passes within one implementation flow.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required.

## Contract

- `ShellFixed`, `ShellSlot`, `ShellElement`, and `ShellFragment` are typed structural values. A slot
  is always one complete child fragment; attributes, scripts, styles, and raw strings cannot become
  slot contexts.
- `prepareShell` uses explicit current-child cursors and closing continuations. Deep shells do not
  recurse on the host stack.
- Element boundaries are obtained from `Std.Html.renderChunks` using a typed shallow element. The
  existing renderer remains authoritative for ordered attributes, escaping, handler blocking, void
  spelling, and trusted markup.
- Children of void elements have no output position and are ignored, matching ordinary `Html`
  rendering. No absent child inside a void element creates a missing-slot failure.
- The compiled result is the existing `Plan`, so each unique used slot renders once per request,
  repeated positions reuse it, and missing slots fail in document order.
- `Compose.documentShell` and `documentShellIn` match the ordinary document helpers exactly while
  replacing the body children with one named typed slot. `Html.Build.Node` remains an `Html` builder
  and composes through `ShellFixed` rather than gaining a parallel child model.

## Measurement

The optimized same-machine probe rendered 5,000 documents with a fixed standard Compose shell and a
changing paragraph body. The ordinary path rebuilt and rendered `Compose.document` each time; the
prepared path compiled `Compose.documentShell` once and filled its body slot per response.

| Measure | Ordinary document | Prepared shell |
|---|---:|---:|
| heap allocated | 3,514,992,160 bytes | 2,262,937,928 bytes |
| process maximum RSS | 93,896,704 bytes | 86,622,208 bytes |
| elapsed | 0.99s | 0.75s |

The prepared shell reduced measured heap allocation by 35.6%, process maximum RSS by 7.7%, and
elapsed time by 24.2%. These figures include compiler and evaluator startup and are one-host
comparative evidence, not service latency, network, or portable complexity guarantees.

## Exact next action

Commit directly to `dev`, post the commit on issue #260, close it, and continue to issue #261,
“Enforce SSR output budgets while rendering dynamic slots.”

## Completion evidence

- `UsesHtmlServer.pudu` checks without diagnostics and returns all 27 focused assertions.
- Exact-output checks cover ordinary and language-qualified document parity, ordered/escaped
  attributes, handler blocking, trusted values, repeated slots, deterministic missing slots, void
  elements, and mixed fixed/slot fragments.
- A 1,600-level shell compiles and renders without recursive host-stack traversal.
- Full repository gate evidence is recorded before delivery.
- `git diff --check` passes; owned source files remain below 500 lines; source, mirrors, MOC,
  changelog, and handoff are aligned.

## Referenced by

[[handoffs/_MOC]] · [[Std Html SSR]] · [[Std Html Compose]] · [[Std Html Build]] · [[src/Std/_MOC]]
