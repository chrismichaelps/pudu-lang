---
type: moc
tags: [moc]
---

# Pudu Wiki Vault

The vault is the source of truth for the [[Pudu Language]]. Implementation is a projection of these pages under [[FMCF Workflow]].

## Maps of Content

- [[architecture/_MOC|Architecture]] — purpose, vocabulary, maturity, and governance dashboard.
- [[domain/_MOC|Domain]] — canonical compiler and language concepts.
- [[grammar/_MOC|Grammar]] — sovereign syntax anchors for Haskell and Pudu.
- [[subsystems/_MOC|Subsystems]] — compiler bounded contexts.
- [[seams/_MOC|Seams]] — external and variable boundaries.
- [[decisions/_MOC|Decisions]] — durable architectural decisions.
- [[src/_MOC|Modules]] — 1:1 mirror of implementation source files.
- [[handoffs/_MOC|Handoffs]] — zero-loss role and session continuity.
- [[CHANGELOG|Changelog]] — temporal ledger of logic changes.

## Private Input Boundary

The original proposal, goal, and FMCF instruction files are local-only inputs and are intentionally ignored. This vault contains their distilled engineering decisions and is the shareable source of truth. Do not copy or quote private input text into repository history.

## Link Policy

Every wiki link must resolve to a versioned page or declared alias. Maps of Content own exhaustive structural membership; each page's `Referenced by` section is a curated set of high-value inbound navigation, not a generated or exhaustive backlink index. Module dependency and consumer links remain explicit in mirrored module pages.

## Referenced by

[[architecture/_MOC]] · [[FMCF Workflow]]
