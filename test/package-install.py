#!/usr/bin/env python3
"""End-to-end checks of `pudu install` as a package manager is used from a terminal.

Packages live in bare git repositories under a temporary directory, reached as
`PUDU_GITHUB_URL=file://…/github`, so resolution and fetching run real git.
Every case checks the exit status, what was printed, and the project's
`pudu.toml`, `pudu.lock`, and `deps/`.

    python3 test/package-install.py --pudu "$(cabal list-bin exe:pudu)"
"""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

FAILURES = []


def check(name, condition, detail=""):
    print(("ok    " if condition else "FAIL  ") + name)
    if not condition:
        FAILURES.append(name)
        if detail:
            print("      " + str(detail).replace("\n", "\n      "))


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class Workspace:
    """Bare repositories, a git environment, and the project under test."""

    def __init__(self, pudu, work):
        self.pudu = pudu
        self.work = work
        self.github = work / "github"
        self.environment = dict(
            os.environ, PUDU_HOME=str(work / "home"), PUDU_GITHUB_URL=f"file://{self.github}", PUDU_MIN_RELEASE_AGE="0", NO_COLOR="1",
            GIT_AUTHOR_NAME="a", GIT_AUTHOR_EMAIL="a@b", GIT_COMMITTER_NAME="a", GIT_COMMITTER_EMAIL="a@b",
        )
        for name in ["PUDU_TOKEN", "PUDU_GITHUB_API", "PUDU_GITHUB_CLIENT_ID", "GITHUB_TOKEN"]:
            self.environment.pop(name, None)

    def run(self, cwd, *args):
        done = subprocess.run([self.pudu, *args], cwd=cwd, env=self.environment, capture_output=True, text=True, timeout=300)
        return done.returncode, done.stdout + done.stderr

    def git(self, cwd, *args):
        return subprocess.run(["git", *args], cwd=cwd, env=self.environment, capture_output=True, text=True, check=True).stdout.strip()

    def publish(self, owner, name, releases):
        """A repository with one tagged commit per (version, manifest extra, module text)."""
        bare = self.github / owner / name
        bare.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True)
        clone = self.work / "clones" / owner / name
        clone.mkdir(parents=True)
        self.git(clone, "init", "-q", "-b", "main")
        self.git(clone, "remote", "add", "origin", str(bare))
        for version, manifest, files in releases:
            write(clone / "pudu.toml", manifest.replace("VERSION", version))
            for path, text in files.items():
                write(clone / path, text)
            self.git(clone, "add", "-A")
            self.git(clone, "commit", "-qm", f"version {version}")
            self.git(clone, "tag", "-a", f"v{version}", "-m", f"v{version}")
        self.git(clone, "push", "-q", "--tags", "origin", "main")
        return bare


def library(name, root, extra=""):
    return f'[package]\nname = "{name}"\nversion = "VERSION"\nroot = "{root}"\n{extra}'


def module(name):
    return {f"src/{name.replace('.', '/')}.pudu": f"module {name}\n\n/// One.\nexport fn one() -> Int {{\n  1\n}}\n"}


class Project:
    """A project's files as the test reads them."""

    def __init__(self, root):
        self.root = root

    def manifest(self):
        return (self.root / "pudu.toml").read_text()

    def lock(self):
        path = self.root / "pudu.lock"
        return path.read_text() if path.exists() else ""

    def state(self):
        return self.manifest(), self.lock()

    def requirement(self, key):
        for line in self.manifest().splitlines():
            if line.startswith(f'"{key}" =') or line.startswith(f"{key} ="):
                return line.split("=", 1)[1].strip()
        return None

    def locked(self, name):
        blocks = self.lock().split("[[package]]")
        for block in blocks:
            if f'name = "{name}"' in block:
                for line in block.splitlines():
                    if line.startswith("version = "):
                        return line.split("=", 1)[1].strip().strip('"')
        return None

    def installed(self, name):
        return (self.root / "deps" / name / "pudu.toml").exists()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pudu", required=True)
    parser.add_argument("--keep", action="store_true", help="keep the working directory")
    arguments = parser.parse_args()
    work = pathlib.Path(tempfile.mkdtemp(prefix="pudu-install-e2e-"))
    space = Workspace(os.path.abspath(arguments.pudu), work)
    try:
        cases(space, work)
    finally:
        if not arguments.keep:
            shutil.rmtree(work, ignore_errors=True)
    if FAILURES:
        print(f"\n{len(FAILURES)} failed")
        sys.exit(1)
    print("\nall install checks passed")


def cases(space, work):
    json_kit = library("@alice/json-kit", "JsonKit")
    space.publish("alice", "json-kit", [(v, json_kit, module("JsonKit.Parse")) for v in ["1.0.0", "1.1.0", "2.0.0", "2.1.0-beta.1"]])
    space.publish("bob", "text", [("1.0.0", library("@bob/text", "Text", '\n[dependencies]\n"@alice/json-kit" = "^1.0"\n'), module("Text.Words"))])
    parser_repo = space.publish("carol", "parser", [("0.4.0", library("parser", "Parser"), module("Parser"))])
    write(work / "geometry" / "pudu.toml", library("geometry", "Geometry").replace("VERSION", "0.1.0"))
    write(work / "geometry" / "src" / "Geometry.pudu", "module Geometry\n")
    code, out = space.run(work, "init", "app")
    check("a new project starts with no dependencies", code == 0, out)
    app = Project(work / "app")
    run = lambda *args: space.run(app.root, *args)

    adding(app, run)
    workflow(app, run)
    sources(app, run, parser_repo)
    transitive(app, run)
    removal(app, run)
    refusals(app, run, space, work)


def adding(app, run):
    code, out = run("install", "@alice/json-kit")
    check("a bare install adds a package not in pudu.toml", code == 0 and "+ @alice/json-kit 2.0.0" in out, out)
    check("it is pinned to ^ of the newest stable release", app.requirement("@alice/json-kit") == '"^2.0.0"', app.manifest())
    check("a pre-release is not chosen when none is asked for", app.locked("@alice/json-kit") == "2.0.0", app.lock())
    check("its files are installed into deps/", app.installed("@alice/json-kit"))
    check("the command says which modules to import", "import JsonKit" in out, out)
    before = app.state()
    code, out = run("install", "@alice/json-kit")
    check("the same install again changes nothing", code == 0 and "Already up to date" in out and app.state() == before, out)
    code, out = run("install", "@alice/json-kit@1.0.0")
    check("an exact version writes =", code == 0 and app.requirement("@alice/json-kit") == '"=1.0.0"', app.manifest())
    check("moving to another version is reported as a change", "~ @alice/json-kit 2.0.0 → 1.0.0" in out and app.locked("@alice/json-kit") == "1.0.0", out)
    code, out = run("install", "@alice/json-kit@^1.0")
    check("a caret range is written as given", code == 0 and app.requirement("@alice/json-kit") == '"^1.0"', app.manifest())
    check("a range the lock satisfies keeps the locked version", app.locked("@alice/json-kit") == "1.0.0", app.lock())
    code, out = run("install", "@alice/json-kit@~1.1.0")
    check("a tilde range the lock does not satisfy moves it", code == 0 and app.requirement("@alice/json-kit") == '"~1.1.0"' and app.locked("@alice/json-kit") == "1.1.0", out)
    code, out = run("install", "@alice/json-kit@>=1.0, <2.0")
    check("a comma range is written as given", code == 0 and app.requirement("@alice/json-kit") == '">=1.0, <2.0"', app.manifest() + out)
    code, out = run("install", "@alice/json-kit@2.1.0-beta.1")
    check("a pre-release named exactly is chosen", code == 0 and app.locked("@alice/json-kit") == "2.1.0-beta.1" and app.requirement("@alice/json-kit") == '"=2.1.0-beta.1"', out)
    code, out = run("install", "@alice/json-kit@1.1.0", "@bob/text")
    check("two packages install in one command", code == 0 and app.requirement("@alice/json-kit") == '"=1.1.0"' and app.requirement("@bob/text") == '"^1.0.0"', app.manifest() + out)


def workflow(app, run):
    shutil.rmtree(app.root / "deps")
    lock = app.lock()
    code, out = run("install")
    check("a clone without deps/ is restored from the lock", code == 0 and app.installed("@alice/json-kit") and app.installed("@bob/text") and app.lock() == lock, out)
    code, out = run("install", "--locked")
    check("--locked passes when the lock matches", code == 0, out)
    manifest = app.manifest()
    (app.root / "pudu.toml").write_text(manifest.replace('"=1.1.0"', '"=1.0.0"'))
    code, out = run("install", "--locked")
    check("--locked refuses a hand-edited requirement and names the change", code != 0 and "1.1.0 -> 1.0.0" in out and app.lock() == lock, out)
    (app.root / "pudu.toml").write_text(manifest)
    code, out = run("deps")
    check("deps lists each requirement with its locked version", code == 0 and "@alice/json-kit  =1.1.0  (locked 1.1.0)" in out and "@bob/text" in out, out)
    code, out = run("tree")
    check("tree shows a package's own dependency beneath it", code == 0 and "@bob/text 1.0.0" in out and out.count("@alice/json-kit") >= 2, out)
    code, out = run("uninstall", "@bob/text")
    (app.root / "pudu.toml").write_text(app.manifest().replace("[dependencies]\n", '[dependencies]\n"@bob/text" = "^1.0.0"\n'))
    code, out = run("install")
    check("a dependency written by hand is installed by plain install", code == 0 and "+ @bob/text 1.0.0" in out and app.installed("@bob/text") and app.requirement("@bob/text") == '"^1.0.0"', out)


def sources(app, run, parser_repo):
    code, out = run("install", "../geometry")
    check("a directory is added under its short name", code == 0 and app.requirement("geometry") == '{ path = "../geometry" }', app.manifest() + out)
    url = f"git+file://{parser_repo}#v0.4.0"
    code, out = run("install", url)
    check("a git URL at a tag is added with its revision", code == 0 and app.requirement("parser") == f'{{ git = "file://{parser_repo}", rev = "v0.4.0" }}', app.manifest() + out)
    check("a git dependency is locked and installed", app.locked("parser") == "0.4.0" and app.installed("parser"), app.lock())


def transitive(app, run):
    check("a package's own dependency is locked and installed", app.locked("@alice/json-kit") == "1.1.0" and app.installed("@alice/json-kit"))
    before = app.state()
    code, out = run("install", "@alice/json-kit@2.0.0")
    check("a requirement that conflicts with a dependency's is refused, naming both", code != 0 and "=2.0.0" in out and "^1.0" in out, out)
    check("a refused conflict changes nothing", app.state() == before)


def removal(app, run):
    code, out = run("uninstall", "@bob/text", "parser")
    check("uninstall removes several dependencies at once", code == 0 and app.requirement("@bob/text") is None and app.requirement("parser") is None, app.manifest() + out)
    check("their lock entries and files are gone", app.locked("@bob/text") is None and not app.installed("@bob/text") and app.locked("parser") is None, app.lock())
    check("a package still required stays", app.locked("@alice/json-kit") == "1.1.0" and app.installed("@alice/json-kit"))
    before = app.state()
    code, out = run("uninstall", "@bob/text")
    check("uninstalling a name not in pudu.toml is refused", code != 0 and "is not a dependency in pudu.toml" in out and app.state() == before, out)


def refusals(app, run, space, work):
    refused = [
        ("a bare word is refused", ["install", "lodash"], "is not something to install"),
        ("a trailing @ is refused", ["install", "@alice/json-kit@"], "names no version"),
        ("an upper-case handle is refused", ["install", "@Alice/json-kit@1.0.0"], "is not a valid handle"),
        ("an unknown option is refused", ["install", "--save-dev", "@alice/json-kit@1.0.0"], "unknown option --save-dev"),
        ("a version never released is refused, listing those that were", ["install", "@alice/json-kit@9.9.9"], "released: 2.1.0-beta.1, 2.0.0, 1.1.0, 1.0.0"),
        ("a repository that does not exist is refused", ["install", "@alice/json-kt@1.0.0"], "json-kt"),
        ("several packages where one is missing install none", ["install", "@bob/text@1.0.0", "@alice/missing"], "missing"),
    ]
    for name, args, said in refused:
        before = app.state()
        code, out = run(*args)
        check(name, code != 0 and said in out and app.state() == before, out)
    code, out = space.run(work, "init", "json-kit")
    owner = Project(work / "json-kit")
    (owner.root / "pudu.toml").write_text(owner.manifest().replace('name = "json-kit"', 'name = "json-kit"\nroot = "JsonKit"'))
    before = owner.state()
    code, out = space.run(owner.root, "install", "@alice/json-kit@1.0.0")
    check("a package owning the project's own module root is refused", code != 0 and "both own the module root JsonKit" in out and owner.state() == before, out)
    outside = work / "outside"
    outside.mkdir()
    code, out = space.run(outside, "install", "@alice/json-kit@1.0.0")
    check("install outside a project says how to start one", code != 0 and "pudu init" in out and not (outside / "pudu.toml").exists(), out)


if __name__ == "__main__":
    main()
