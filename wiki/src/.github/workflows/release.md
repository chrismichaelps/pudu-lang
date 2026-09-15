---
type: workflow
path: "@root/.github/workflows/release.yml"
fidelity: Active
tags: [ci, release, packaging, linux, macos]
aliases: [Release Workflow]
---
# Release Workflow

Publishes a release of the compiler, and proves one before it is merged.

- **Trigger.** A push to `main` or to a `release/` branch that changes `packages/pudu/**`. A push that
  changes only the README, the website, the examples, or the wiki does not start the workflow.
- **Plan.** [[Release Plan]] runs its own tests, then decides from the ref, the package version, the
  existing tags, and the paths the push changed. It releases only from `main`, only for a compiler
  change, and only at a version with no tag; a `release/` branch builds without publishing.
- **Archives.** On `ubuntu-24.04` (`linux-amd64`) and `macos-14` (`darwin-arm64`), the package is built
  at `-O2` by `scripts/build-package.py` and packed by `scripts/package-binary.py`, which checks the
  binary's version and the API lifecycle. The checksum is verified, the archive is unpacked into a
  temporary directory, and its `bin/pudu` must report the version and run a program there with an
  empty environment, so the standard library is found beside the executable and not in the checkout.
- **Publish.** Only when the plan says release: the commit receives an annotated `vX.Y.Z` tag from
  the workflow's own identity, and a GitHub release is created from that tag with both archives,
  their checksums, and `packages/pudu/v0.1/release-notes/X.Y.Z.md` as its notes, marked pre-release
  for a `0.x` version. An existing tag stops the job rather than publishing twice.

No input from an issue, a pull request, or a commit message reaches a shell command; the branch name
and plan outputs are passed through the environment.

Resolved Grill Log: releasing on a manually pushed tag was rejected because `main` must stay the only
source of a release and the version file the only statement of it. Path filtering alone was not
enough, because a compiler change that did not raise the version would publish the same version
again; the tag check closes that. The manual `package` workflow remains for building an archive from
any branch.
