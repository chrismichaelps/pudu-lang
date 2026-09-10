---
type: workflow
path: "@root/.github/workflows/website-linux.yml"
fidelity: Active
tags: [ci, website, linux, artifact]
aliases: [Website Linux Artifact Workflow]
---
# Website Linux Artifact Workflow

Builds the Pudu compiler on an x86-64 Linux runner, uses that compiler to bundle the Pudu website,
and uploads the executable as a short-lived artifact. It runs for feature branches that change the
website or the workflow and can also be dispatched after it reaches the repository's default branch.

The workflow does not deploy, publish the private book, or hold Vercel credentials. The local
release operator downloads the artifact, assembles canonical static output, and performs the
authenticated preview deployment.

Resolved Grill Log: remote Linux construction replaces an unavailable local build host; the
artifact is architecture-specific, expires after one day, and cannot bypass local route/browser
validation or the Vercel preview gate.
