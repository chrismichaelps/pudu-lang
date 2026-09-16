---
type: script
path: "@root/scripts/release-plan.py"
fidelity: Active
tags: [release, packaging, ci]
aliases: [Release Plan]
---
# Release Plan

Decides what a push does for [[Release Workflow]], printing `build`, `release`, `prerelease`, `tag`,
`version`, and `notes` as `key=value` lines.

`plan(ref, version, tags, changed, notesExist)` is the whole decision:

- `release` holds only on `main`, when a changed path is under `packages/pudu/`, and when `vVERSION` is
  not already a tag;
- `build` holds when releasing, or on a `release/` branch that changed the package;
- `prerelease` holds for a `0.x` version;
- a release whose notes file is missing is refused rather than published without notes.

The command reads the version through `scripts/package_info.py`, the tags from `git`, and the changed
paths from the push's previous commit on `main`. A `release/` branch, and a push that created its
branch, is compared with where it left `origin/main`, because a release branch proves everything its
merge will bring rather than only its latest push.

`test/release-plan.test.py` holds the decision: a compiler change on `main` at a new version releases
as a pre-release; README, website, example, and wiki changes never build or release; an existing tag
is never released again; a release branch builds without publishing; `dev` does nothing; and missing
notes refuse a release. CI and `test/gates.sh` run it.

Resolved Grill Log: the decision is a pure function beside its command so it is tested without git
or a runner, which is the only way a rule meant to stop an accidental publish can be checked before
it is needed.
