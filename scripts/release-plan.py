#!/usr/bin/env python3
"""Decide whether a push releases the compiler, and how.

A release is cut from `main`, only when the push changed the compiler package
under `packages/pudu/`, and only when the package's version has no tag yet. A
merge that changes the README, the website, the examples, or the wiki releases
nothing, and neither does a later compiler change that did not raise the version.
A `release/` branch builds and checks the archives without publishing them, so a
release can be proven before it is merged.

The decision is printed as `key=value` lines for a workflow's outputs.
"""
import argparse
from pathlib import Path
import subprocess
import sys

from package_info import load_package

PACKAGE_PREFIX = "packages/pudu/"


def plan(ref, version, tags, changed, notes_exist):
  """The decision for one push, as a dictionary of strings."""
  package_changed = any(path.startswith(PACKAGE_PREFIX) for path in changed)
  tag = "v" + version
  on_main = ref == "main"
  on_release_branch = ref.startswith("release/")
  release = on_main and package_changed and tag not in tags
  build = release or (on_release_branch and package_changed)
  if release and not notes_exist:
    raise ValueError(f"release notes for {version} are missing")
  return {
    "build": str(build).lower(),
    "release": str(release).lower(),
    "prerelease": str(version.split(".")[0] == "0").lower(),
    "tag": tag,
    "version": version,
  }


def notes_path(package, version):
  return package / "release-notes" / f"{version}.md"


def git(*arguments):
  return subprocess.run(["git", *arguments], check=True, text=True, capture_output=True).stdout


def changed_paths(ref, before, after, base):
  """The paths a push changed. A release branch is compared with where it left
  `base` as a whole, because what it proves is everything its merge will bring;
  so is a push that created its branch and has no previous commit."""
  if ref.startswith("release/") or not before or set(before) == {"0"}:
    before = git("merge-base", base, after).strip()
  return [line for line in git("diff", "--name-only", before, after).splitlines() if line]


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--ref", required=True)
  parser.add_argument("--before", default="")
  parser.add_argument("--after", required=True)
  parser.add_argument("--base", default="origin/main")
  args = parser.parse_args()
  root = Path(__file__).resolve().parent.parent
  try:
    package, version, _ = load_package(root)
    tags = set(git("tag", "--list").split())
    changed = changed_paths(args.ref, args.before, args.after, args.base)
    decision = plan(args.ref, version, tags, changed, notes_path(package, version).is_file())
  except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as problem:
    parser.error(str(problem))
  decision["notes"] = notes_path(package, version).relative_to(root).as_posix()
  for key, value in decision.items():
    print(f"{key}={value}")


if __name__ == "__main__":
  sys.exit(main())
