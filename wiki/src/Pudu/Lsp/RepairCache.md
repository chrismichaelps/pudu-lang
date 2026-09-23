---
type: module
path: "@root/src/Pudu/Lsp/RepairCache.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp, cache]
aliases: [Lsp Repair Cache]
---

# LSP Repair Cache

## Purpose

Keep the analyses of repaired texts while nothing they read has changed, so a completion asked
again at the same place — as an editor does while the reader pauses — compiles nothing.

## Interface

```haskell
data RepairCache
newRepairCache :: IO (IORef RepairCache)
repairCapacity :: Int
cachedAnalyse  :: IORef RepairCache -> Int -> Text -> (Text -> IO Analysis) -> Text -> IO Analysis
```

### Governance

- An entry is keyed by the documents' generation ([[Lsp Documents]]), the document's URI, and the
  exact repaired text. A generation is one state of every open document and of the disk as the
  server last heard of it; any edit, open, close, or file event starts a new one, and the first
  lookup in a new generation drops every older entry. A cached analysis therefore never answers
  for a state it was not made from.
- At most `repairCapacity` analyses are kept, most recently used first. An analysis holds a whole
  program's products, which is why the bound is small.
- What a repair produced is kept whether or not it answered the request: asking again would
  produce the same.
- A written document that already answers is never repaired, so ordinary completion never reaches
  the cache.

### Linkage

- **Requires:** [[Lsp Documents]].
- **Consumed by:** [[Lsp Server]]; tested with a counting analyser in the server spec.

## Negative Logic (Prohibited Paths)

- Do not key an entry by cursor offset or document text alone.
- Do not let entries outlive the generation they were made in.

## Grill Log

- **Q:** Why a generation instead of fingerprints of every source a repair read? **A:** The server
  already hears of every change that could matter. _Rationale:_ one counter is exact and costs
  nothing per request; hashing every open buffer and dependency per request would cost more than
  the lookups it saves for small programs. _Rejected:_ a content fingerprint per request.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]] · [[Lsp Documents]]
