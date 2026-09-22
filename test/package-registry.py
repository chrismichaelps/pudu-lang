#!/usr/bin/env python3
"""End-to-end checks of `pudu` against a local package registry.

Starts `registry/src/Main.pudu` on a free port with a fresh data directory,
creates an account, and drives login, push, release, install, update,
upgrade, private projects, the minimum release age, name suggestions, and
archive integrity through the `pudu` binary given. Exits non-zero on the
first failed check.

    python3 test/package-registry.py --pudu "$(cabal list-bin exe:pudu)"
"""

import argparse
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURES = []


def check(name, condition, detail=""):
    print(("ok    " if condition else "FAIL  ") + name)
    if not condition:
        FAILURES.append(name)
        if detail:
            print("      " + detail.replace("\n", "\n      "))


def free_port():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def library(root, version, handle="alice", name="json-kit"):
    write(root / "pudu.toml", f'[package]\nname = "@{handle}/{name}"\nversion = "{version}"\ndescription = "JSON helpers"\nkeywords = ["json"]\n')
    write(root / "src" / "JsonKit" / "Parse.pudu", "module JsonKit.Parse\n\nexport fn one() -> Int {\n  1\n}\n")
    write(root / "README.md", "# Json Kit\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pudu", required=True)
    parser.add_argument("--keep", action="store_true", help="keep the working directory")
    arguments = parser.parse_args()
    pudu = os.path.abspath(arguments.pudu)
    work = pathlib.Path(tempfile.mkdtemp(prefix="pudu-registry-e2e-"))
    port = free_port()
    url = f"http://127.0.0.1:{port}"
    data = work / "data"
    environment = dict(os.environ, PUDU_HOME=str(work / "home"), PUDU_REGISTRY=url, NO_COLOR="1")
    environment.pop("PUDU_TOKEN", None)
    environment.pop("PUDU_MIN_RELEASE_AGE", None)

    def run(args, cwd, extra=None):
        env = dict(environment, **(extra or {}))
        done = subprocess.run([pudu] + args, cwd=cwd, env=env, capture_output=True, text=True, timeout=300)
        return done.returncode, done.stdout + done.stderr

    registry = ["run", str(ROOT / "registry" / "src" / "Main.pudu")]
    code, token = run(registry + ["account", "--data", str(data), "--handle", "alice", "--password", "correct-horse"], work)
    token = token.strip()
    check("the registry creates an account and prints a token", code == 0 and token.startswith("pudu_"), token)
    def start():
        started = subprocess.Popen([pudu] + registry + ["serve", "--data", str(data), "--port", str(port)], cwd=work, env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(150):
            try:
                urllib.request.urlopen(url + "/health", timeout=1)
                break
            except OSError:
                time.sleep(0.2)
        return started

    server = start()
    try:
        lib = work / "lib"
        library(lib, "1.0.0")
        code, out = run(["login", "--token", token], lib)
        check("login stores a token the registry accepts", code == 0 and "signed in as @alice" in out, out)
        mode = oct((work / "home" / "credentials.toml").stat().st_mode & 0o777)
        check("the credentials file is private to its owner", mode == "0o600", mode)
        code, out = run(["release", "1.0.0"], lib)
        check("release checks the project and publishes", code == 0 and "checked 1 modules" in out and "released @alice/json-kit 1.0.0" in out, out)
        code, out = run(["release", "1.0.0"], lib)
        check("a released version cannot be released again", code != 0 and "already released" in out, out)
        code, out = run(["push"], lib)
        check("push uploads a snapshot", code == 0 and "pushed @alice/json-kit" in out, out)

        app = work / "app"
        write(app / "pudu.toml", '[package]\nname = "app"\n')
        write(app / "src" / "Main.pudu", "module Main\n\nimport JsonKit.Parse as Parse\n\nexport fn main() -> Int {\n  Parse.one() - 1\n}\n")
        code, out = run(["install", "@alice/json-kit"], app)
        check("a release younger than the minimum age is not chosen by a range", code != 0 and "minimum release age" in out, out)
        code, out = run(["install", "@alice/json-kit"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("install resolves, locks, and installs a registry package", code == 0 and "+ @alice/json-kit 1.0.0" in out, out)
        lock = (app / "pudu.lock").read_text()
        check("the lock records the registry and the archive digest", f"registry+{url}" in lock and 'checksum = "sha256:' in lock, lock)
        check("the manifest gains a caret requirement", '"@alice/json-kit" = "^1.0.0"' in (app / "pudu.toml").read_text())
        code, out = run(["run", "src/Main.pudu"], app)
        check("the installed module is imported by its name", code == 0, out)
        server.terminate()
        server.wait(timeout=10)
        code, out = run(["install", "--verbose"], app)
        check("a lock and a warm cache install while the registry is down", code == 0 and "Already up to date" in out and "fetching" not in out, out)
        server = start()
        shutil.rmtree(app / "deps")
        code, out = run(["install", "--offline"], app)
        check("--offline restores deps/ from the cache", code == 0 and (app / "deps" / "@alice" / "json-kit" / "pudu.toml").exists(), out)

        library(lib, "1.1.0")
        run(["release", "1.1.0"], lib)
        library(lib, "2.0.0")
        run(["release", "2.0.0"], lib)
        code, out = run(["update"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("update stays within the requirement", code == 0 and "1.0.0 → 1.1.0" in out, out)
        code, out = run(["upgrade"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("upgrade raises the requirement and names the major version", code == 0 and "a new major version" in out and '"^2.0.0"' in (app / "pudu.toml").read_text(), out)

        code, out = run(["install", "@alice/json-kt"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("a misspelled name suggests the real one", code != 0 and "did you mean @alice/json-kit" in out, out)

        secret = work / "secret"
        write(secret / "pudu.toml", '[package]\nname = "@alice/secret-kit"\nversion = "0.1.0"\n')
        write(secret / "src" / "SecretKit" / "Core.pudu", "module SecretKit.Core\n\nexport fn two() -> Int {\n  2\n}\n")
        code, out = run(["release", "0.1.0", "--private"], secret)
        check("a private release is published", code == 0, out)
        other = work / "other"
        write(other / "pudu.toml", '[package]\nname = "other"\n')
        code, out = run(["install", "@alice/secret-kit@0.1.0"], other)
        check("its owner installs a private package", code == 0, out)
        stranger = work / "stranger"
        write(stranger / "pudu.toml", '[package]\nname = "stranger"\n')
        code, out = run(["install", "@alice/secret-kit@0.1.0"], stranger, {"PUDU_HOME": str(work / "stranger-home")})
        check("a private package does not exist to others", code != 0 and "is not a project" in out, out)

        checksum = [line for line in (app / "pudu.lock").read_text().splitlines() if line.startswith("checksum")][0].split("sha256:")[1].strip('"')
        cache = work / "home" / "cache"
        shutil.rmtree(cache / "releases" / f"sha256-{checksum}")
        with open(cache / "archives" / f"sha256-{checksum}.tar.gz", "ab") as damaged:
            damaged.write(b"x")
        shutil.rmtree(app / "deps")
        code, out = run(["install"], app)
        check("a damaged cached archive is downloaded again", code == 0 and (app / "deps" / "@alice" / "json-kit").exists(), out)

        code, out = run(["logout"], lib)
        check("logout forgets the token", code == 0 and "signed out" in out, out)
        code, out = run(["whoami"], lib)
        check("after logout there is no account", code != 0 and "not signed in" in out, out)
    finally:
        server.terminate()
        server.wait(timeout=10)
        if not arguments.keep:
            shutil.rmtree(work, ignore_errors=True)
    if FAILURES:
        print(f"\n{len(FAILURES)} failed")
        sys.exit(1)
    print("\nall registry checks passed")


if __name__ == "__main__":
    main()
