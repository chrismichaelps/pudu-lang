#!/usr/bin/env python3
"""The release decision: only a compiler change on main, at an untagged version,
publishes; documentation, website, and example merges never do."""
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
SPEC = importlib.util.spec_from_file_location("release_plan", ROOT / "scripts" / "release-plan.py")
release_plan = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release_plan)

COMPILER = ["packages/pudu/v0.1/src/Pudu/Eval.hs"]


def decide(ref="main", version="0.1.0", tags=(), changed=COMPILER, notes=True):
  return release_plan.plan(ref, version, set(tags), list(changed), notes)


class ReleasePlan(unittest.TestCase):
  def test_compiler_change_on_main_at_a_new_version_releases(self):
    decision = decide()
    self.assertEqual(decision["release"], "true")
    self.assertEqual(decision["build"], "true")
    self.assertEqual(decision["tag"], "v0.1.0")

  def test_a_zero_major_version_is_a_prerelease(self):
    self.assertEqual(decide()["prerelease"], "true")
    self.assertEqual(decide(version="1.0.0")["prerelease"], "false")

  def test_documentation_website_and_examples_never_release(self):
    for changed in (
      ["README.md"],
      ["website/docs/02-getting-started.md", "website/public/site.css"],
      ["examples/web/Notes.pudu"],
      ["wiki/CHANGELOG.md", "CONTRIBUTING.md"],
      [],
    ):
      with self.subTest(changed=changed):
        decision = decide(changed=changed)
        self.assertEqual(decision["release"], "false")
        self.assertEqual(decision["build"], "false")

  def test_an_existing_tag_is_never_released_again(self):
    decision = decide(tags=["v0.1.0"])
    self.assertEqual(decision["release"], "false")
    self.assertEqual(decision["build"], "false")

  def test_a_release_branch_builds_without_publishing(self):
    decision = decide(ref="release/0.1.0")
    self.assertEqual(decision["build"], "true")
    self.assertEqual(decision["release"], "false")

  def test_other_branches_do_nothing(self):
    decision = decide(ref="dev")
    self.assertEqual(decision["build"], "false")
    self.assertEqual(decision["release"], "false")

  def test_a_release_needs_its_notes(self):
    with self.assertRaises(ValueError):
      decide(notes=False)
    self.assertEqual(decide(changed=["README.md"], notes=False)["release"], "false")


if __name__ == "__main__":
  unittest.main()
