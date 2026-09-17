#!/usr/bin/env python3
"""Prepare, check, and measure Pudu's submission to GitHub Linguist.

GitHub's language bar counts only languages Linguist lists. Listing one takes a
pull request to github-linguist/linguist carrying a `languages.yml` entry, a
TextMate grammar, and real-world samples, and Linguist accepts it only once the
extension is in use well beyond one project. This script keeps those three
parts buildable from what the repository already has, so the submission is one
command on the day the usage is there.

  linguist.py check [--pudu PUDU]    the parts exist and agree with each other
  linguist.py usage                  how far public usage is from the threshold
  linguist.py prepare LINGUIST_DIR   write the submission into a Linguist checkout

`check` runs in CI. `usage` asks GitHub's code search through `gh`, which must
be signed in. `prepare` edits a local clone of Linguist and nothing else: the
pull request, `script/add-grammar`, and `script/update-ids` are run by hand in
that clone, because Linguist's own tooling owns those steps.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENTRY = ROOT / "editors" / "linguist" / "language.yml"
GRAMMAR = ROOT / "editors" / "vscode" / "syntaxes" / "pudu.tmLanguage.json"
ATTRIBUTES = ROOT / ".gitattributes"
REPOSITORY = "chrismichaelps/pudu-lang"
GRAMMAR_SOURCE = "https://github.com/" + REPOSITORY

# Real programs from this repository, not tutorial examples: Linguist refuses
# "hello world" samples, and a classifier trained on toy code learns little.
SAMPLES = [
  "packages/pudu/v0.1/lib/Std/Process.pudu",
  "packages/pudu/v0.1/lib/Std/Http/Server/Route.pudu",
  "website/src/Service/Docs.pudu",
  "website/src/Function.pudu",
]

# Linguist's published bar for an extension that occurs many times in one
# repository: files indexed in the last year, excluding forks, spread across
# many owners.
FILE_THRESHOLD = 2000
# Linguist gives no number for the spread; this is the floor below which a
# reviewer's random sample would plainly be dominated by a handful of users.
REPOSITORY_FLOOR = 200
# Code search answers at most this many results for one query.
SEARCH_CEILING = 1000
# Code search allows ten requests a minute for a signed-in user.
SEARCH_PAUSE_SECONDS = 7

HEX_COLOR = re.compile(r"^#[0-9a-f]{6}$")
MINIMUM_SAMPLE_LINES = 40


def read_entry():
  """The entry as a mapping, read without a YAML dependency.

  The file is Linguist's own shape: one top-level name, two-space keys, and
  `- ` list items. Anything else is refused rather than guessed at."""
  name = None
  fields = {}
  current_list = None
  for number, line in enumerate(ENTRY.read_text().splitlines(), start=1):
    if not line.strip() or line.lstrip().startswith("#"):
      continue
    if not line.startswith(" "):
      if name is not None or not line.endswith(":"):
        raise ValueError(f"{ENTRY.name}:{number}: expected exactly one language name")
      name = line[:-1]
    elif line.startswith("  - ") and current_list is not None:
      fields[current_list].append(unquote(line[4:]))
    elif line.startswith("  ") and ":" in line:
      key, _, value = line.strip().partition(":")
      value = value.strip()
      if value:
        fields[key] = unquote(value)
        current_list = None
      else:
        fields[key] = []
        current_list = key
    else:
      raise ValueError(f"{ENTRY.name}:{number}: unrecognised line {line!r}")
  if name is None:
    raise ValueError(f"{ENTRY.name}: no language name")
  return name, fields


def name_of_entry():
  return read_entry()[0]


def unquote(value):
  return value[1:-1] if len(value) >= 2 and value[0] == value[-1] == '"' else value


def check(pudu):
  """Every part of the submission exists and agrees with the others."""
  problems = []
  name, fields = read_entry()
  if name != "Pudu":
    problems.append(f"the entry names {name!r}, not 'Pudu'")
  if fields.get("type") != "programming":
    problems.append("the entry's type is not 'programming'")
  if "language_id" in fields:
    problems.append("language_id is assigned by Linguist's script/update-ids; remove it")
  if not HEX_COLOR.match(fields.get("color", "")):
    problems.append("the colour is not a lowercase #rrggbb value")
  if fields.get("extensions") != [".pudu"]:
    problems.append("the extensions are not exactly ['.pudu']")

  grammar = json.loads(GRAMMAR.read_text())
  if grammar.get("scopeName") != fields.get("tm_scope"):
    problems.append(
      f"the grammar's scope {grammar.get('scopeName')!r} is not the entry's tm_scope {fields.get('tm_scope')!r}"
    )
  if grammar.get("name") != name:
    problems.append(f"the grammar is named {grammar.get('name')!r}, not {name!r}")
  if not grammar.get("patterns"):
    problems.append("the grammar has no patterns")

  for sample in SAMPLES:
    path = ROOT / sample
    if not path.is_file():
      problems.append(f"sample {sample} does not exist")
      continue
    lines = path.read_text().splitlines()
    if len(lines) < MINIMUM_SAMPLE_LINES:
      problems.append(f"sample {sample} has {len(lines)} lines; Linguist wants real programs")
    if pudu:
      checked = subprocess.run([pudu, "check", str(path)], capture_output=True, text=True, cwd=ROOT)
      if checked.returncode != 0:
        problems.append(f"sample {sample} does not compile\n{(checked.stderr or checked.stdout).strip()}")

  attributes = ATTRIBUTES.read_text() if ATTRIBUTES.is_file() else ""
  if not re.search(r"^\*\.pudu\s.*linguist-language=Pudu\b", attributes, re.M):
    problems.append(".gitattributes does not name *.pudu as Pudu")

  for problem in problems:
    print("FAIL", problem, file=sys.stderr)
  if problems:
    return 1
  print(f"linguist submission is consistent: {len(SAMPLES)} samples, scope {fields['tm_scope']}")
  return 0


def search_page(page):
  answered = subprocess.run(
    [
      "gh", "api", "-X", "GET", "search/code",
      "-f", "q=extension:pudu",
      "-f", "per_page=100",
      "-f", f"page={page}",
    ],
    capture_output=True,
    text=True,
  )
  if answered.returncode != 0:
    raise RuntimeError((answered.stderr or answered.stdout).strip())
  return json.loads(answered.stdout)


def usage():
  """How many public `.pudu` files and repositories code search can see."""
  try:
    first = search_page(1)
  except (OSError, RuntimeError) as problem:
    print(f"code search is unavailable: {problem}", file=sys.stderr)
    print("sign in with `gh auth login` and run this again", file=sys.stderr)
    return 1
  total = first["total_count"]
  owners = set()
  repositories = set()
  items = list(first["items"])
  page = 2
  while len(items) < min(total, SEARCH_CEILING):
    time.sleep(SEARCH_PAUSE_SECONDS)
    more = search_page(page)["items"]
    if not more:
      break
    items.extend(more)
    page += 1
  for item in items:
    repository = item["repository"]
    if repository.get("fork"):
      continue
    repositories.add(repository["full_name"])
    owners.add(repository["owner"]["login"])
  outside = repositories - {REPOSITORY}

  print(f"indexed .pudu files:       {total} (Linguist asks for {FILE_THRESHOLD})")
  sampled = " (from the first {} results)".format(len(items)) if total > len(items) else ""
  print(f"repositories{sampled}: {len(repositories)}, {len(outside)} outside this one")
  print(f"distinct owners:           {len(owners)}")
  ready = total >= FILE_THRESHOLD and len(outside) >= REPOSITORY_FLOOR
  if ready:
    print("usage meets Linguist's bar: run `linguist.py prepare` and open the pull request")
  else:
    print("usage is below Linguist's bar: a pull request now would be closed unreviewed")
  return 0 if ready else 2


def prepare(linguist):
  """Write the entry and the samples into a clone of Linguist."""
  languages = linguist / "lib" / "linguist" / "languages.yml"
  if not languages.is_file():
    print(f"{linguist} is not a Linguist checkout: no {languages.relative_to(linguist)}", file=sys.stderr)
    return 1
  if check(None) != 0:
    return 1

  entry = "".join(
    line + "\n"
    for line in ENTRY.read_text().splitlines()
    if line.strip() and not line.lstrip().startswith("#")
  )
  text = languages.read_text()
  if re.search(r"^Pudu:$", text, re.M):
    print("languages.yml already lists Pudu; leaving it as it is")
  else:
    # Linguist keeps the file sorted by name, compared byte for byte, and its
    # tests fail an entry out of place. The entry goes before the first name that sorts after it; nothing
    # else moves, since re-sorting the whole file with a different collation
    # would rewrite thousands of lines that are not this change's.
    blocks = re.split(r"(?m)^(?=[^\s#-])", text)
    position = len(blocks)
    for index, block in enumerate(blocks):
      heading = block.split("\n", 1)[0]
      if re.match(r"^[^\s#][^:]*:$", heading) and heading[:-1] > name_of_entry():
        position = index
        break
    blocks.insert(position, entry)
    languages.write_text("".join(blocks))
    print(f"added Pudu to {languages.relative_to(linguist)}")

  samples = linguist / "samples" / "Pudu"
  samples.mkdir(parents=True, exist_ok=True)
  for sample in SAMPLES:
    source = ROOT / sample
    target = samples / source.name
    shutil.copyfile(source, target)
    print(f"copied {sample} -> {target.relative_to(linguist)}")

  print()
  print("Finish in the Linguist checkout:")
  print(f"  script/add-grammar {GRAMMAR_SOURCE}")
  print("  script/update-ids")
  print("  bundle exec rake test")
  print("Samples are Apache-2.0, the licence of this repository; say so in the pull request,")
  print("and link the code search results `linguist.py usage` reports.")
  return 0


def main():
  parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  commands = parser.add_subparsers(dest="command", required=True)
  checking = commands.add_parser("check", help="verify the submission's parts agree")
  checking.add_argument("--pudu", help="also compile every sample with this compiler")
  commands.add_parser("usage", help="measure public usage against Linguist's bar")
  preparing = commands.add_parser("prepare", help="write the submission into a Linguist clone")
  preparing.add_argument("linguist", type=Path)
  arguments = parser.parse_args()

  if arguments.command == "check":
    return check(arguments.pudu)
  if arguments.command == "usage":
    return usage()
  return prepare(arguments.linguist.resolve())


if __name__ == "__main__":
  sys.exit(main())
