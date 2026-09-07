---
type: module
path: "@root/lib/Std/App/Flag.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, feature-flags, rollouts, targeting]
aliases: [Std App Flag]
---

# Std App Flag

## Purpose and interface

Pure value-based feature flag evaluator supporting targeted rollouts, gradual percentage canary releases, allowlist targeting, and kill switches without external service calls or centralized network bottlenecks.

Exports:
- `type Strategy = Disabled | Enabled | Percentage(Int) | Allowlist(Array[Str])`: Flag activation policy.
- `type Context = { subjectId: Str, tenantId: Str }`: Evaluation context carrying subject and tenant identifiers.
- `type Flag = { name: Str, strategy: Strategy }`: Feature flag definition.
- `context(subjectId: Str, tenantId: Str) -> Context`: Builds an evaluation context.
- `flag(name: Str, strategy: Strategy) -> Flag`: Creates a feature flag.
- `isEnabled(flag: &Flag, context: &Context) -> Bool`: Evaluates whether the flag is active for the given context. Percentage evaluations use deterministic hash buckets ($0..99$), guaranteeing sticky consistency across server workers and distributed cluster nodes.

## Complexity and limits

Evaluation executes in $O(1)$ for boolean and percentage strategies, and $O(M)$ linear scan for allowlists where $M$ is the number of targeted entities. Percentage hashing is pure, deterministic, and requires no inter-process communication.

## Grill Log

- **Q:** How is stickiness guaranteed without a centralized database? **A:** The percentage rollout computes an arithmetic hash of `flag.name + ":" + context.subjectId` modulo 100. The same subject evaluating the same flag always lands in the same bucket on every node.
- **Q:** What if `subjectId` is empty? **A:** If neither `subjectId` nor `tenantId` is supplied for a percentage or allowlist rollout, the evaluation safely defaults to `false`.

## Dependencies and consumers

- Consumed by SSR application routes, UI components, API migrations, and Canary release pipelines.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]] · [[WEB]]
