#!/usr/bin/env python3
"""Check every Pudu example in the documentation.

The documentation promises that each example is a complete program that runs as
written, so each fenced `pudu` block in `website/docs/` is written to a file
named for its module and put through the compiler, then run. Every example is
expected to finish on its own: the one that can listen for requests asks for a
flag before it does, so nothing here is excused from running and an example that
begins to hang is a failure rather than an exception someone has to maintain.

Usage: docs-examples.py [--pudu <executable>] [--run] [--jobs N]
"""
import argparse
import concurrent.futures
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "website" / "docs"
BLOCK = re.compile(r"^```pudu\n(.*?)^```", re.S | re.M)
MODULE = re.compile(r"^module\s+([A-Za-z_][A-Za-z0-9_.]*)", re.M)
TEST_IMPORT = re.compile(r"^import\s+Std\.Test\b", re.M)


def examples():
  """Every fenced Pudu block, as (chapter, index, module name, source)."""
  found = []
  for chapter in sorted(DOCS.glob("*.md")):
    for index, match in enumerate(BLOCK.finditer(chapter.read_text()), start=1):
      source = match.group(1)
      name = MODULE.search(source)
      if not name:
        found.append((chapter.name, index, None, source))
      else:
        found.append((chapter.name, index, name.group(1), source))
  return found


def place(directory, module, source):
  """Write one example where its module header says it lives."""
  program = directory / Path(*module.split(".")).with_suffix(".pudu")
  program.parent.mkdir(parents=True, exist_ok=True)
  program.write_text(source)
  return program


def verify(pudu, chapter, index, module, source, run, chaptermates):
  """Check one example, and run it when it is expected to finish.

  A chapter may build a project across several examples, so the others are laid
  out beside this one at their own module paths and this one is written last:
  an example that imports a sibling finds it, and an example that revises a
  module earlier in the chapter is the copy that gets checked."""
  where = f"{chapter} example {index}"
  if module is None:
    return where, False, "no module declaration"
  directory = Path(tempfile.mkdtemp(prefix="pudu-docs-"))
  try:
    for other, othersource in chaptermates:
      if other is not None and other != module:
        place(directory, other, othersource)
    program = place(directory, module, source)
    checked = subprocess.run(
      [pudu, "check", str(program)], capture_output=True, text=True, timeout=120
    )
    if checked.returncode != 0:
      return where, False, "check failed\n" + (checked.stderr or checked.stdout).strip()
    if not run:
      return where, True, "checked"
    # A suite reports through Std.Test and answers the runner, not a reader, so
    # it is driven by the command that reads that report.
    command = "test" if TEST_IMPORT.search(source) else "run"
    try:
      ran = subprocess.run(
        [pudu, command, str(program)],
        capture_output=True,
        text=True,
        timeout=60,
        cwd=directory,
      )
    except subprocess.TimeoutExpired:
      return where, False, f"{command} did not finish within 60s"
    if ran.returncode != 0:
      detail = (ran.stderr or ran.stdout).strip() or f"exit status {ran.returncode} with no output"
      return where, False, f"{command} failed\n" + detail
    return where, True, command + "ran"
  finally:
    shutil.rmtree(directory, ignore_errors=True)


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--pudu", default="pudu", help="the compiler to check with")
  parser.add_argument("--run", action="store_true", help="also run each example")
  parser.add_argument("--jobs", type=int, default=8)
  arguments = parser.parse_args()

  found = examples()
  if not found:
    print("no examples were found in", DOCS, file=sys.stderr)
    return 1

  siblings = {}
  for chapter, _, module, source in found:
    siblings.setdefault(chapter, []).append((module, source))

  failures = []
  with concurrent.futures.ThreadPoolExecutor(max_workers=arguments.jobs) as pool:
    work = [
      pool.submit(
        verify, arguments.pudu, chapter, index, module, source, arguments.run, siblings[chapter]
      )
      for chapter, index, module, source in found
    ]
    for done in concurrent.futures.as_completed(work):
      where, ok, detail = done.result()
      if not ok:
        failures.append((where, detail))

  print(f"{len(found)} examples checked", end="")
  print(" and run" if arguments.run else "")
  for where, detail in sorted(failures):
    print(f"\nFAIL {where}\n{detail}", file=sys.stderr)
  if failures:
    print(f"\n{len(failures)} of {len(found)} examples failed", file=sys.stderr)
    return 1
  return 0


if __name__ == "__main__":
  sys.exit(main())
