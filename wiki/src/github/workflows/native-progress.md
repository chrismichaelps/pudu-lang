---
type: module
path: "@root/.github/workflows/native-progress.yml"
fidelity: Active
aliases: [Native Progress Workflow]
---
# Native Progress Workflow

## Purpose and interface

Validate progress tooling on pull requests; refresh [[Repository README]] after
pushes to dev (including merged PRs), or manual dispatch. Read-only validation
uses Node 22 tests. Only the publishing job receives contents:write and it never
runs on a pull request. Serialize publishing without cancelling an active push.

Publishing checks out current dev, tests the tooling, regenerates only README,
checks output, and commits only README when it changes. On a non-fast-forward
race, fetch current dev and recompute, up to three attempts. No force push.
The scoped GITHUB_TOKEN bot commit does not trigger another workflow run.

## Operational boundary

As verified for #496, dev is unprotected. This authorized generated-document
commit is the narrow exception to feature-PR delivery; implementation still
requires a reviewed PR. If protection is enabled, permit this publishing job or
change publication to a maintenance PR. Permission/push failures remain failed
checks, never silently successful updates. Hosted execution is unverified until
integration; local generator tests do not prove GitHub permissions.

## Resolved Grill Log

- **Q:** Execute PR code with write privileges? **A:** No; write permission is job-scoped
  and publishing only executes trusted dev code after integration.
- **Q:** Publish the triggering SHA after a newer merge? **A:** No; fetch and recompute
  current dev on every attempt.
- **Q:** Stage unrelated files? **A:** No; stage README only and never force-push.

## Dependencies and consumers

[[Native Progress Generator]] · [[Native Progress Tests]] · [[Repository README]]

## Referenced by

[[src/_MOC]] · [[Native C11 Backend Delivery]]
