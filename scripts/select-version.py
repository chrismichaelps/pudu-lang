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
        if not (root / name).is_symlink():
            parser.error(f"refusing to replace non-link path: {name}")
    manifest = (package / "pudu.cabal").read_text()
    version = re.search(r"^version:\s*([0-9]+)\.([0-9]+)(?:\.[0-9]+)*\s*$", manifest, re.MULTILINE)
    if version is None or f"v{version[1]}.{version[2]}" != args.series:
        parser.error("package version does not match its series directory")
    current = root / "packages/pudu/current"
    if not current.is_symlink():
        parser.error("refusing to replace a non-link current package")
    temporary = root / "packages/pudu/.current.selecting"
    try:
        temporary.symlink_to(args.series, target_is_directory=True)
    except FileExistsError:
        parser.error("another selection is pending: .current.selecting")
    try:
        os.replace(temporary, current)
    finally:
        if temporary.is_symlink():
            temporary.unlink()
    print(f"selected {args.series}")


if __name__ == "__main__":
    main()
