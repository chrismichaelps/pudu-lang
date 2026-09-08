#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from package_info import load_package


def version(text):
    if not isinstance(text, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", text):
        raise ValueError("version must have three numeric components")
    return tuple(map(int, text.split(".")))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("schedule", "check"))
    parser.add_argument("module", nargs="?")
    parser.add_argument("name", nargs="?")
    parser.add_argument("--binary")
    parser.add_argument("--package")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        package, current_text, configuration = load_package(root, args.package)
    except (OSError, ValueError, KeyError) as problem:
        parser.error(str(problem))
    current = version(current_text)
    policy_path = root / "api-lifecycle.json"
    policy = json.loads(policy_path.read_text())
    if policy.get("schema") != 1 or not isinstance(policy.get("removals"), list):
        parser.error("unsupported API lifecycle policy")
    records = policy["removals"]
    seen = set()
    for record in records:
        key = (record["module"], record["name"])
        if key in seen:
            parser.error("duplicate API lifecycle identity")
        seen.add(key)
        version(record["deprecatedIn"])
        if not re.fullmatch(r"Std(?:\.[A-Za-z_][A-Za-z_0-9]*)+", key[0]) or not key[1]:
            parser.error("invalid standard-library API identity")
    if args.command == "schedule":
        if not args.module or not args.name:
            parser.error("schedule requires a module and exported name")
        if not re.fullmatch(r"Std(?:\.[A-Za-z_][A-Za-z_0-9]*)+", args.module):
            parser.error("module must name a standard-library module")
        if (args.module, args.name) in seen:
            parser.error("API already has a removal policy")
        records.append({"module": args.module, "name": args.name, "deprecatedIn": current_text})
        temporary = policy_path.with_suffix(".pending")
        with temporary.open("x") as stream:
            json.dump(policy, stream, indent=2)
            stream.write("\n")
        os.replace(temporary, policy_path)
        return
    if not args.binary:
        parser.error("check requires --binary")
    binary = str(Path(args.binary).resolve())
    reported = subprocess.run([binary, "version"], check=True, text=True, capture_output=True).stdout.strip()
    if reported != f"pudu {current_text}":
        parser.error("binary and selected package versions differ")
    active = [record for record in records if current >= version(record["deprecatedIn"])]
    modules = {record["module"] for record in active}
    paths = [package / "lib" / Path(*name.split(".")).with_suffix(".pudu") for name in sorted(modules)]
    existing = [str(path) for path in paths if path.is_file()]
    exports = set()
    if existing:
        env = dict(os.environ, PUDU_LIB=str(package / "lib"))
        result = subprocess.run([binary, "api", "--json", *existing], check=True,
                                text=True, capture_output=True, cwd=package, env=env)
        index = json.loads(result.stdout)
        if index["version"] != current_text:
            parser.error("API index version differs from package")
        exports = {(entry["module"], entry["name"]) for entry in index["exports"]}
    failures = []
    for record in active:
        key = (record["module"], record["name"])
        due = current > version(record["deprecatedIn"])
        if due and key in exports:
            failures.append(f"{key[0]}.{key[1]} must be removed after {record['deprecatedIn']}")
        if not due and key not in exports:
            failures.append(f"{key[0]}.{key[1]} disappeared in its deprecation release")
    if failures:
        parser.error("; ".join(failures))


if __name__ == "__main__":
    main()
