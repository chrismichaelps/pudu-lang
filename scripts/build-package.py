#!/usr/bin/env python3
import argparse
from pathlib import Path
import subprocess
import sys
from package_info import load_package


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        package, version, configuration = load_package(root, args.package)
        subprocess.run(configuration["build"], cwd=package, check=True, stdout=sys.stderr)
        located = subprocess.run(configuration["locateBinary"], cwd=package, check=True,
                                 text=True, capture_output=True).stdout.strip()
        if not located or "\n" in located:
            parser.error("backend must return exactly one executable path")
        binary = (package / located).resolve(strict=True)
        if not binary.is_file():
            parser.error("backend did not produce a regular executable file")
        reported = subprocess.run([str(binary), "version"], check=True, text=True,
                                  capture_output=True, timeout=30).stdout.strip()
        if reported != f"pudu {version}":
            parser.error("backend executable does not report the package version")
        print(binary)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as problem:
        parser.error(str(problem))


if __name__ == "__main__":
    main()
