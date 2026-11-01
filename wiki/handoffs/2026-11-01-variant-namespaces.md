---
type: handoff
status: ACTIVE
aliases: [Variant Namespace Delivery]
tags: [handoff, resolution, nominal]
---
# Variant Namespace Delivery

Issue #766; feature/766-variant-namespaces starts from fetched dev 9742e0ca
and explicitly integrates tested named publication e9094219 (#772).
Architect resolves candidate identity and use precedence. Semantic Engineer
owns Resolve/Context/Canonical/State, Type.Check.Pattern/Expression and Compiler.Literals; Runtime Engineer owns Eval.Record and the variant-fact comment in Type.Env. Verification Engineer owns
VariantNamespaceSpec, the ResolveSpec coordinator, test manifest and sum-owners.
Forensic Guardian owns corresponding mirrors, MOCs and changelog. Independent
review is waived for this delivery loop. No delegated agents. Preserve other work.

## Role transitions

Architect → Semantic Engineer: resolve the candidate/precedence contract before
implementation. Semantic Engineer → Verification Engineer: exercise structured
resolution and loaded execution before Forensic Guardian parity and delivery.

Qualified-head counterexample 6559534361 is verified before repair: a type One
and variants One in two sums must still permit One.Chosen and One.One. Context
exposes a qualified-head operation preferring a known type over a variant alias;
Canonical uses it only for member and multi-segment constructor heads. Bare uses
stay ambiguous. The initial full gate was stopped and is not final evidence.

## Resolved Grill Log

Variants from distinct sums must coexist before qualified uses are walked.
Index local candidates by variant spelling and declaring type in invocation-owned
state. Keep the first symbol for each owner, so duplicate variants within one
sum retain E2001 and its first declaration span. Record every distinct candidate
symbol, but install only the first bare alias. A second sum's variant must not
re-enter same-frame ordinary declaration conflict handling. Genuine ordinary
value/type duplicates and existing non-variant conflicts remain unchanged.

Pass the declaring type name at collection. Remove the quadratic spelling tally
and separate ambiguity list: complete candidates are already collected before
any body. A use reports E2012 only when its resolved value binding is a variant
alias and more than one owner offers it. A nearer local value therefore shadows
the alias normally. Attach every candidate declaration as related information;
do not choose an owner by declaration order. Qualified uses retain the existing
head-only resolver and the checked canonical owner selection from #772.

Use the current pure state/context boundary, not a global registry. Keep symbol
IDs unique and symbol inventory complete; an unbound duplicate candidate gets no
false lexical binding. Candidate storage starts empty for each module and cannot
leak through discarded function scopes. No typing admission, public runtime shape or import visibility policy changes belong in this partition.

Required evidence: qualified same-labelled unit/tuple/named variants with each
owner in both evaluators and off/cold/warm caches; ambiguous bare constructor and
pattern E2012 with all related spans; local shadow success; same-owner duplicate
E2001 and ordinary duplicate value/type refusal; unknown/arity diagnostics.
Structured resolution properties run in the real test coordinator. The focused
source gate and clean full optimized gate must pass. Keep the PR below 600
changed lines and publish after prerequisite #772 merges.

## Checked constructor projection

Architect → Semantic/Runtime Engineer: canonicalVariant records VariantOwner at
use spans, including generated canonical references. Executable Name/Member
constructor values lower to an empty internal ::constructor::/owner/label record
expression; Eval.Record returns the owned positional constructor directly. No
installer aliases or runtime namespace lookup are needed. Named-value refusal,
public wire shapes, authored tooling syntax and spans remain unchanged.

## Validation and delivery

Structured namespace properties and the expanded loaded owner gate pass in both
evaluators, declaration orders and cache modes, including retained and folded
constructors whose qualifier shares a variant label. The fresh clean full
optimized repository gate passes, including all Ark, package, CLI, LSP and derive
checks. Introduced wiki links resolve and tracked private inputs are absent.
Forensic Guardian → Release Owner: parity and validation are complete; independent
review is waived. Prerequisite #772 is merged as 65b1efed.

Exact next action: publish this tested repair to dev, then continue #761's
remaining owner/evidence audit before the Binary derive facade and engine work.

## Referenced by

[[handoffs/_MOC]] · [[Name Resolution]] · [[Resolve Context]] · [[Resolve State]] · [[Variant Namespace Properties]] · [[Sum Owner Gate]]
