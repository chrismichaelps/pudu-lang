#!/usr/bin/env python3
import argparse
from pathlib import Path
import re
import os


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("series")
    args = parser.parse_args()
    if not re.fullmatch(r"v[0-9]+\.[0-9]+", args.series):
        parser.error("series must have the form v0.1")
    root = Path(__file__).resolve().parent.parent
    relative = Path("packages/pudu") / args.series
    package = root / relative
    names = ("src", "app", "cbits", "lib", "pudu.cabal")
    for name in names:
        if not (package / name).exists():
            parser.error(f"package is missing {name}")
    manifest = (package / "pudu.cabal").read_text()
    version = re.search(r"^version:\s*([0-9]+)\.([0-9]+)(?:\.[0-9]+)*\s*$", manifest, re.MULTILINE)
    if version is None or f"v{version[1]}.{version[2]}" != args.series:
        parser.error("package version does not match its series directory")
    project = root / "cabal.project"
    contents, count = re.subn(r"^packages:.*$", f"packages: {relative.as_posix()}",
                              project.read_text(), count=1, flags=re.MULTILINE)
    if count != 1:
        parser.error("cabal.project must contain a packages field")
    temporary = project.with_suffix(".selecting")
    with temporary.open("x") as stream:
        stream.write(contents)
    try:
        os.replace(temporary, project)
    finally:
        if temporary.exists():
            temporary.unlink()
    print(f"selected {args.series}")


if __name__ == "__main__":
    main()
