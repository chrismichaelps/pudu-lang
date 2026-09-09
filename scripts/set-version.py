#!/usr/bin/env python3
import argparse
import os
from pathlib import Path
import re
import stat
import tempfile

from package_info import load_package


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("version")
  parser.add_argument("--package")
  args = parser.parse_args()
  if not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", args.version):
    parser.error("version must contain three numeric components without leading zeros")
  root = Path(__file__).resolve().parent.parent
  try:
    package, previous, configuration = load_package(root, args.package)
    if package.parent != (root / "packages/pudu").resolve():
      raise ValueError("versioned packages must be directly inside packages/pudu")
    expected = "v" + ".".join(args.version.split(".")[:2])
    if package.name != expected:
      raise ValueError(f"version {args.version} belongs in packages/pudu/{expected}")
    if tuple(map(int, args.version.split("."))) < tuple(map(int, previous.split("."))):
      raise ValueError("package versions cannot move backwards")
    source = configuration["versionSource"]
    path = (package / source["file"]).resolve(strict=True)
    original = path.read_text()
    if source["format"] == "cabal":
      updated, count = re.subn(
        r"^(version:[ \t]*)\S+",
        lambda match: match[1] + args.version,
        original,
        flags=re.MULTILINE,
      )
      if count != 1:
        raise ValueError("Cabal manifest must declare exactly one version")
    else:
      updated = args.version + "\n"
    if updated != original:
      temporary = None
      try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".version-", delete=False) as stream:
          temporary = Path(stream.name)
          os.fchmod(stream.fileno(), stat.S_IMODE(path.stat().st_mode))
          stream.write(updated)
          stream.flush()
          os.fsync(stream.fileno())
        if path.read_text() != original:
          raise ValueError("version source changed during the update; retry")
        os.replace(temporary, path)
      finally:
        if temporary is not None:
          temporary.unlink(missing_ok=True)
    print(f"{package.relative_to(root)}: {previous} -> {args.version}")
  except (OSError, ValueError, KeyError, TypeError) as problem:
    parser.error(str(problem))


if __name__ == "__main__":
  main()
