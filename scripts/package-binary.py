#!/usr/bin/env python3
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from package_info import load_package
import sys
import tarfile
import tempfile


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--binary", required=True)
  parser.add_argument("--target", required=True)
  parser.add_argument("--package")
  parser.add_argument("--output", default="dist/packages")
  args = parser.parse_args()
  if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)+", args.target):
    parser.error("target must be a platform identifier such as linux-amd64")
  root = Path(__file__).resolve().parent.parent
  try:
    package, version, configuration = load_package(root, args.package)
  except (OSError, ValueError, KeyError) as problem:
    parser.error(str(problem))
  binary = Path(args.binary).resolve(strict=True)
  if not binary.is_file():
    parser.error("binary is not a regular file")
  reported = subprocess.run(
    [str(binary), "version"],
    check=True,
    text=True,
    capture_output=True,
    timeout=30
  ).stdout.strip()
  if reported != f"pudu {version}":
    parser.error("binary and package versions differ")
  subprocess.run(
    [
      sys.executable,
      str(root / "scripts/api-lifecycle.py"),
      "check",
      "--binary",
      str(binary),
      "--package",
      str(package)
    ],
    check=True
  )
  sources = sorted((package / "lib" / "Std").rglob("*.pudu"))
  if not sources:
    parser.error("standard library is empty")
  output = (root / args.output).resolve()
  output.mkdir(parents=True, exist_ok=True)
  name = f"pudu-{version}-{args.target}"
  archive = output / f"{name}.tar.gz"
  checksum = output / f"{name}.tar.gz.sha256"
  if archive.exists() or checksum.exists():
    parser.error("output already exists")
  epoch = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
  if epoch < 0:
    parser.error("SOURCE_DATE_EPOCH must be nonnegative")
  with tempfile.TemporaryDirectory(prefix=".pudu-package-", dir=output) as scratch:
    stage = Path(scratch) / name
    executable = stage / "bin" / ("pudu.exe" if binary.suffix == ".exe" else "pudu")
    executable.parent.mkdir(parents=True)
    shutil.copyfile(binary, executable)
    executable.chmod(0o755)
    for source in sources:
      if source.is_symlink() or not source.resolve().is_relative_to(package):
        parser.error("standard library must contain package-owned regular files")
      target = stage / "lib" / "pudu" / source.relative_to(package / "lib")
      target.parent.mkdir(parents=True, exist_ok=True)
      shutil.copyfile(source, target)
    shutil.copyfile(package / "LICENSE", stage / "LICENSE")
    metadata = {
      "name": "pudu",
      "version": version,
      "target": args.target,
      "backend": configuration["backend"],
      "executable": executable.relative_to(stage).as_posix(),
      "standardLibrary": "lib/pudu",
      "systemLibrariesBundled": False
    }
    (stage / "package.json").write_text(json.dumps(metadata, sort_keys=True) + "\n")
    staged_archive = Path(scratch) / archive.name
    with staged_archive.open("wb") as raw:
      with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w") as bundle:
          for path in sorted(stage.rglob("*")):
            info = bundle.gettarinfo(str(path), arcname=f"{name}/{path.relative_to(stage).as_posix()}")
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            info.mtime = epoch
            info.mode = 0o755 if path.is_dir() or path == executable else 0o644
            if path.is_file():
              with path.open("rb") as content:
                bundle.addfile(info, content)
            else:
              bundle.addfile(info)
    digest = hashlib.sha256()
    with staged_archive.open("rb") as content:
      for block in iter(lambda: content.read(1024 * 1024), b""):
        digest.update(block)
    staged_checksum = Path(scratch) / checksum.name
    staged_checksum.write_text(f"{digest.hexdigest()}  {archive.name}\n")
    os.link(staged_checksum, checksum)
    try:
      os.link(staged_archive, archive)
    except BaseException:
      checksum.unlink()
      raise
  print(archive)


if __name__ == "__main__":
  main()

