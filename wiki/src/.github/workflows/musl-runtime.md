---
type: workflow
path: "@root/.github/workflows/musl-runtime.yml"
fidelity: Active
tags: [ci, runtime, musl, linux, vercel]
aliases: [Musl Runtime Workflow]
---
# Musl Runtime Workflow

Builds the Pudu runtime inside Alpine on an x86-64 runner, proves that the result has no glibc
dependency, attaches a small Pudu program, and executes that program in both Alpine and Amazon
Linux 2 before uploading the runtime as a short-lived artifact.

Installed GHCup tool locations are resolved explicitly and added to later workflow steps. This
avoids relying on installer shell state that GitHub Actions does not preserve between steps.

Resolved Grill Log: the artifact is accepted only after its actual loader dependencies and behavior
are checked on both the build libc and the older Lambda-compatible host.
