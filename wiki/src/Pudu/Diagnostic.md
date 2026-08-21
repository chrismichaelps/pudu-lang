---
type: module
path: "@root/src/Pudu/Diagnostic.hs"
fidelity: Active
domain: "[[Diagnostic]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.57
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Diagnostic Model]
---

# Diagnostic Model

> `{-| @Diagnostic.Compiler.Module — stabilizes actionable compiler failures -}`

## Purpose

Represent phase-independent structured [[Diagnostic]] values with stable codes, spans, help, related locations, and deterministic ordering. Rendering is intentionally outside the first model slice.

## Interface

### Signatures

```haskell
newtype DiagnosticCode = DiagnosticCode { unDiagnosticCode :: Text }
  deriving stock (Eq, Ord, Show)

data Severity = Error | Warning | Note
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data Related = Related
  { relatedSpan :: !Span
  , relatedMessage :: !Text
  }
  deriving stock (Eq, Show)

data Diagnostic -- constructor hidden; Eq and Show

diagnostic :: DiagnosticCode -> Severity -> Span -> Text -> Diagnostic
diagnosticCode :: Diagnostic -> DiagnosticCode
diagnosticSeverity :: Diagnostic -> Severity
diagnosticSpan :: Diagnostic -> Span
diagnosticMessage :: Diagnostic -> Text
diagnosticHelp :: Diagnostic -> Maybe Text
diagnosticRelated :: Diagnostic -> [Related]
withHelp :: Text -> Diagnostic -> Diagnostic
withRelated :: Related -> Diagnostic -> Diagnostic
sortDiagnostics :: [Diagnostic] -> [Diagnostic]
hasErrors :: [Diagnostic] -> Bool
```

### Governance

- Codes use the groups in [[architecture/SEMANTICS#Diagnostic Contract]].
- `withRelated` preserves insertion order for explanatory causality.
- Deterministic ordering is source name, start, end, severity rank (`Error`, `Warning`, `Note`), then code. Message, help, and ordered related-location data are total tie-breakers.
- Messages are non-empty developer-facing text. An empty internal message is replaced deterministically with the diagnostic code so renderers never receive an empty primary message.
- The `Diagnostic` constructor and writable record fields are hidden so callers cannot bypass message normalization; explicit accessors are read-only.

### Linkage

- **Requires:** [[Source]], [[Diagnostic]], [[grammar/haskell]].
- **Consumed by:** every later compiler phase.

## Algorithm

1. Construct a base diagnostic with no help/related items, normalizing an empty message to a stable code-based fallback.
2. Decorators add help or append related locations without changing code/severity/span.
3. Sort by the primary location/severity/code key, then all remaining observable fields, so parallel or recovery paths cannot reorder distinct output nondeterministically.
4. Detect blocking errors by severity only, never code prefixes or rendered text.

## Negative Logic (Prohibited Paths)

- No raw host exceptions or process stderr as messages without translation.
- No severity inferred from a code string.
- No deduplication by message text.
- No public construction or record update that bypasses primary-message normalization.
- No rendering/color/terminal width in the model.

## Edge Cases

- Multiple diagnostics may share a span/code when distinct related context exists; phase owners suppress cascades.
- Related locations may be in other sources.
- Empty related list and absent help are ordinary.
- Empty input message becomes `compiler diagnostic <code>`; this is an internal-defect fallback, not a user-facing phase template.

## Depth

DEPTH 0.57 (MEDIUM). The interface centralizes a durable cross-phase product contract but rendering and registry validation will deepen it later. Deletion would scatter ordering and error-gate policy across phases.

## Grill Log

- **Q:** Store diagnostic messages as variants or text? **A:** Store stable code plus rendered-neutral text initially; later registries can centralize templates. _Rationale:_ exact phase contexts vary while codes carry compatibility. _Rejected:_ untyped text only; enormous closed diagnostic sum before feature set exists.
- **Q:** Deduplicate diagnostics centrally? **A:** No. _Rationale:_ only the emitting phase knows causal equivalence. _Rejected:_ span/message set deduplication that hides legitimate findings.
- **Q:** Is warning an error under warnings-as-errors? **A:** That is CLI policy, not model severity mutation. _Rationale:_ preserve semantic classification. _Rejected:_ rewriting warning values.
- **Q:** May callers construct or update diagnostic records directly? **A:** No; the type is opaque and exposes read-only accessors plus invariant-preserving decorators. _Rationale:_ otherwise an empty primary message could bypass normalization. _Rejected:_ exporting `Diagnostic(..)` or writable record labels.
- **Q:** Is a stable partial key deterministic enough? **A:** No; after location, severity, and code, compare every remaining observable field. _Rationale:_ stable sort alone preserves nondeterministic producer order for equal primary keys. _Rejected:_ relying on input order for distinct diagnostics.
- **Q:** Replace the short related-location list with a sequence now? **A:** No; causality lists are expected to remain small and no profile identifies decoration as a bottleneck. _Rationale:_ preserve a minimal public model until allocation evidence justifies a representation change. _Rejected:_ speculative container dependency.

## Variants

- A diagnostic registry module will later validate code uniqueness and provide canonical templates.

## Referenced by

[[src/Pudu/_MOC]] · [[Source]] · [[Diagnostic]]
