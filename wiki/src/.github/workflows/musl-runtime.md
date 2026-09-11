---
type: workflow
path: "@root/.github/workflows/musl-runtime.yml"
fidelity: Active
tags: [ci, runtime, musl, linux, vercel]
aliases: [Musl Runtime Workflow]
---
# Musl Runtime Workflow

Builds the Pudu runtime inside Alpine on an x86-64 runner and creates an additional Lambda copy whose
ELF interpreter points to the packaged musl loader under `/var/task`. It attaches a small Pudu program
to that copy and executes it in both Alpine and Amazon Linux 2 before uploading the artifacts.

Installed GHCup tool locations are resolved explicitly and added to later workflow steps. This
avoids relying on installer shell state that GitHub Actions does not preserve between steps.

Resolved Grill Log: the artifact is accepted only after its actual loader dependencies, packaged
Lambda path, and behavior are checked on both the build libc and the older Lambda-compatible host.
