#!/usr/bin/env python3
"""End-to-end checks of `pudu` against a local package registry and a stand-in GitHub.

Starts a GitHub stand-in (OAuth device flow, `/user`, repositories backed by
bare git repositories in a temporary directory, commit archives from
`git archive`), then `registry/src/Main.pudu` pointed at it, and drives
login, push, release, install, update, upgrade, private repositories, the
minimum release age, name suggestions, archive integrity, and the registry's
refusals through the `pudu` binary given. Exits non-zero if any check fails.

    python3 test/package-registry.py --pudu "$(cabal list-bin exe:pudu)"
"""

import argparse
import gzip
import hashlib
import http.server
import io
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURES = []
TOKENS = {"gho_alice": "alice", "gho_bob": "bob"}


def check(name, condition, detail=""):
    print(("ok    " if condition else "FAIL  ") + name)
    if not condition:
        FAILURES.append(name)
        if detail:
            print("      " + str(detail).replace("\n", "\n      "))


def free_port():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def crafted(entries):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w", format=tarfile.USTAR_FORMAT) as archive:
        for name, kind, data in entries:
            info = tarfile.TarInfo("alice-evil-kit-0000000/" + name)
            info.type = kind
            if kind == tarfile.REGTYPE:
                info.size = len(data)
                archive.addfile(info, io.BytesIO(data))
            else:
                info.linkname = "/etc/passwd"
                archive.addfile(info)
    return gzip.compress(buffer.getvalue())


EVIL_MANIFEST = b'[package]\nname = "@alice/evil-kit"\nversion = "1.0.0"\n'
EVIL = {
    "link": crafted([("pudu.toml", tarfile.REGTYPE, EVIL_MANIFEST), ("src/link", tarfile.SYMTYPE, b"")]),
    "hardlink": crafted([("pudu.toml", tarfile.REGTYPE, EVIL_MANIFEST), ("src/copy", tarfile.LNKTYPE, b"")]),
    "parent": crafted([("pudu.toml", tarfile.REGTYPE, EVIL_MANIFEST), ("src/../../escape", tarfile.REGTYPE, b"x")]),
    "duplicate": crafted([("pudu.toml", tarfile.REGTYPE, EVIL_MANIFEST), ("pudu.toml", tarfile.REGTYPE, EVIL_MANIFEST)]),
    "std": crafted([("pudu.toml", tarfile.REGTYPE, EVIL_MANIFEST + b'root = "Std"\n')]),
    "other": crafted([("pudu.toml", tarfile.REGTYPE, b'[package]\nname = "@bob/other"\nversion = "1.0.0"\n')]),
    "bomb": gzip.compress(b"\0" * (64 * 1024 * 1024 + 512)),
}


class GitHub(http.server.BaseHTTPRequestHandler):
    """The part of GitHub the registry and `pudu login` use."""

    repositories = {}
    polls = {}

    def log_message(self, *_):
        pass

    def answer(self, status, body, kind="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def login(self):
        header = self.headers.get("Authorization", "")
        return TOKENS.get(header[len("Bearer "):]) if header.startswith("Bearer ") else None

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        form = dict(urllib.parse.parse_qsl(self.rfile.read(length).decode()))
        if self.path == "/login/device/code":
            if form.get("client_id") != "test-client":
                return self.answer(400, {"error": "incorrect_client_credentials"})
            return self.answer(200, {"device_code": "device-1", "user_code": "WXYZ-2345", "verification_uri": "https://github.com/login/device", "interval": 1, "expires_in": 900})
        if self.path == "/login/oauth/access_token":
            count = GitHub.polls.get(form.get("device_code"), 0)
            GitHub.polls[form.get("device_code")] = count + 1
            if count == 0:
                return self.answer(200, {"error": "authorization_pending"})
            return self.answer(200, {"access_token": "gho_alice", "token_type": "bearer", "scope": form.get("scope", "")})
        self.answer(404, {"message": "Not Found"})

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        login = self.login()
        parts = path.strip("/").split("/")
        if path == "/user":
            return self.answer(200, {"login": login, "name": login.title(), "avatar_url": f"https://avatars.example/{login}", "html_url": f"https://github.com/{login}", "type": "User"}) if login else self.answer(401, {"message": "Bad credentials"})
        if parts[0] == "users" and len(parts) == 2:
            return self.answer(200, {"login": parts[1], "name": parts[1].title(), "avatar_url": f"https://avatars.example/{parts[1]}", "html_url": f"https://github.com/{parts[1]}", "type": "User"})
        if parts[0] != "repos" or len(parts) < 3:
            return self.answer(404, {"message": "Not Found"})
        owner, name = parts[1], parts[2]
        repository = GitHub.repositories.get((owner, name))
        if repository is None or (repository["private"] and login != owner):
            return self.answer(404, {"message": "Not Found"})
        if len(parts) == 3:
            permissions = {"pull": True, "push": login == owner, "admin": login == owner} if login else {}
            return self.answer(200, {"name": name, "owner": {"login": owner}, "private": repository["private"], "default_branch": "main", "description": "From GitHub", "topics": ["pudu"], "html_url": f"https://github.com/{owner}/{name}", "permissions": permissions})
        reference = "/".join(parts[4:])
        if name == "evil-kit":
            if parts[3] == "commits":
                case = reference[1:] if reference.startswith("v") else reference
                return self.answer(200, {"sha": "evil-" + case}) if case in EVIL else self.answer(404, {"message": "No commit found"})
            return self.answer(200, EVIL[reference[len("evil-"):]], "application/x-gzip")
        bare = repository["bare"]
        if parts[3] == "commits":
            done = subprocess.run(["git", "--git-dir", bare, "rev-parse", "--verify", "--quiet", reference + "^{commit}"], capture_output=True, text=True)
            return self.answer(200, {"sha": done.stdout.strip()}) if done.returncode == 0 else self.answer(404, {"message": "No commit found"})
        if parts[3] == "tarball":
            prefix = f"{owner}-{name}-{reference[:7]}/"
            done = subprocess.run(["git", "--git-dir", bare, "archive", "--format=tar.gz", "--prefix=" + prefix, reference], capture_output=True)
            return self.answer(200, done.stdout, "application/x-gzip") if done.returncode == 0 else self.answer(404, {"message": "Not Found"})
        self.answer(404, {"message": "Not Found"})


def call(method, url, body=None, headers=None):
    request = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(request, timeout=60) as answered:
            return answered.status, answered.read()
    except urllib.error.HTTPError as refused:
        return refused.code, refused.read()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pudu", required=True)
    parser.add_argument("--keep", action="store_true", help="keep the working directory")
    parser.add_argument("--snapshot", help="also write the website's package data here")
    arguments = parser.parse_args()
    pudu = os.path.abspath(arguments.pudu)
    work = pathlib.Path(tempfile.mkdtemp(prefix="pudu-registry-e2e-"))
    github_port, port = free_port(), free_port()
    github = f"http://127.0.0.1:{github_port}"
    url = f"http://127.0.0.1:{port}"
    data = work / "data"
    environment = dict(os.environ, PUDU_HOME=str(work / "home"), PUDU_LIB=str(ROOT / "packages" / "pudu" / "v0.1" / "lib"), PUDU_REGISTRY=url, NO_COLOR="1", GIT_AUTHOR_NAME="a", GIT_AUTHOR_EMAIL="a@b", GIT_COMMITTER_NAME="a", GIT_COMMITTER_EMAIL="a@b")
    for name in ["PUDU_TOKEN", "PUDU_MIN_RELEASE_AGE"]:
        environment.pop(name, None)

    stand_in = http.server.ThreadingHTTPServer(("127.0.0.1", github_port), GitHub)
    threading.Thread(target=stand_in.serve_forever, daemon=True).start()

    def run(args, cwd, extra=None):
        env = dict(environment, **(extra or {}))
        done = subprocess.run([pudu] + args, cwd=cwd, env=env, capture_output=True, text=True, timeout=300)
        return done.returncode, done.stdout + done.stderr

    def git(cwd, *args):
        return subprocess.run(["git", *args], cwd=cwd, env=environment, capture_output=True, text=True, check=True).stdout

    def repository(owner, name, private=False):
        bare = work / "github" / owner / (name + ".git")
        bare.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True)
        GitHub.repositories[(owner, name)] = {"bare": str(bare), "private": private}
        clone = work / "clones" / name
        clone.mkdir(parents=True)
        git(clone, "init", "-q", "-b", "main")
        git(clone, "remote", "add", "origin", str(bare))
        return clone

    def library(root, version, name="@alice/json-kit"):
        write(root / "pudu.toml", f'[package]\nname = "{name}"\nversion = "{version}"\ndescription = "JSON helpers"\nkeywords = ["json"]\n')
        write(root / "src" / "JsonKit" / "Parse.pudu", "module JsonKit.Parse\n\n/// The number one, parsed.\nexport fn one() -> Int {\n  1\n}\n")
        write(root / "src" / "JsonKit" / "Value.pudu", "module JsonKit.Value\n\n/// A JSON value.\nexport type Value = Text(Str) | Number(Int)\n\n/// The text of a value, or the empty text.\nexport fn textOf(value: Value) -> Str {\n  match value {\n    case Text(held) => held\n    case Number(_) => \"\"\n  }\n}\n")
        write(root / "README.md", "# Json Kit\n\nParse and build JSON values.\n\n```pudu\nimport JsonKit.Parse as Parse\n```\n")
        git(root, "add", "-A")
        git(root, "commit", "-qm", f"version {version}")
        git(root, "push", "-q", "origin", "main")

    registry = ["run", str(ROOT / "registry" / "src" / "Main.pudu"), "serve", "--data", str(data), "--port", str(port), "--github-client-id", "test-client", "--github-url", github, "--github-api", github]

    def start():
        output = open(work / "registry.log", "w")
        started = subprocess.Popen([pudu] + registry, cwd=work, env=environment, stdout=output, stderr=output)
        output.close()
        for _ in range(300):
            try:
                urllib.request.urlopen(url + "/health", timeout=1)
                return started, True
            except OSError:
                if started.poll() is not None:
                    break
                time.sleep(0.2)
        return started, False

    server, ready = start()
    try:
        check("the registry starts", ready, (work / "registry.log").read_text())
        if not ready:
            sys.exit(1)
        lib = repository("alice", "json-kit")
        library(lib, "1.0.0")
        code, out = run(["login"], lib)
        check("login runs GitHub's device flow and stores the token", code == 0 and "enter the code WXYZ-2345" in out and "signed in as @alice" in out, out)
        mode = oct((work / "home" / "credentials.toml").stat().st_mode & 0o777)
        check("the credentials file is private to its owner", mode == "0o600", mode)
        code, out = run(["whoami"], lib)
        check("whoami names the GitHub account", code == 0 and "@alice" in out, out)
        code, out = run(["push"], lib)
        check("push registers the project from its repository", code == 0 and "registered @alice/json-kit from https://github.com/alice/json-kit" in out, out)
        code, out = run(["release", "1.0.0"], lib)
        check("release checks the project, tags it, pushes the tag, and publishes", code == 0 and "checked 2 modules" in out and "tagged v1.0.0" in out and "released @alice/json-kit 1.0.0" in out, out)
        tags = subprocess.run(["git", "--git-dir", GitHub.repositories[("alice", "json-kit")]["bare"], "tag"], capture_output=True, text=True).stdout
        check("the tag is on GitHub", "v1.0.0" in tags, tags)
        code, out = run(["release", "1.0.0"], lib)
        check("a released version cannot be released again", code != 0 and "already released" in out, out)
        manifest = (lib / "pudu.toml").read_text()
        (lib / "pudu.toml").write_text(manifest.replace('version = "1.0.0"', 'version = "1.0.1"'))
        code, out = run(["release", "1.0.1"], lib)
        check("a release refuses a working tree with changes", code != 0 and "not committed" in out, out)
        (lib / "pudu.toml").write_text(manifest)
        code, out = run(["release", "1.0.0"], lib, {"PUDU_TOKEN": "gho_bob"})
        check("an account that cannot push may not release", code != 0 and "cannot push" in out, out)

        app = work / "app"
        write(app / "pudu.toml", '[package]\nname = "app"\n')
        write(app / "src" / "Main.pudu", "module Main\n\nimport JsonKit.Parse as Parse\n\nexport fn main() -> Int {\n  Parse.one() - 1\n}\n")
        code, out = run(["install", "@alice/json-kit"], app)
        check("a release younger than the minimum age is not chosen by a range", code != 0 and "minimum release age" in out, out)
        code, out = run(["install", "@alice/json-kit"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("install resolves, locks, and installs a registry package", code == 0 and "+ @alice/json-kit 1.0.0" in out, out)
        lock = (app / "pudu.lock").read_text()
        check("the lock records the registry and the archive digest", f"registry+{url}" in lock and 'checksum = "sha256:' in lock, lock)
        code, out = run(["run", "src/Main.pudu"], app)
        check("the installed module is imported by its name", code == 0, out)
        server.terminate()
        server.wait(timeout=10)
        code, out = run(["install", "--verbose"], app)
        check("a lock and a warm cache install while the registry is down", code == 0 and "Already up to date" in out and "fetching" not in out, out)
        server, ready = start()
        check("the registry restarts", ready, (work / "registry.log").read_text())
        if not ready:
            sys.exit(1)
        shutil.rmtree(app / "deps")
        code, out = run(["install", "--offline"], app)
        check("--offline restores deps/ from the cache", code == 0 and (app / "deps" / "@alice" / "json-kit" / "pudu.toml").exists(), out)

        git(lib, "push", "-q", "origin", ":refs/tags/v1.0.0")
        shutil.rmtree(work / "home" / "cache")
        shutil.rmtree(app / "deps")
        code, out = run(["install"], app)
        check("a deleted tag changes no locked build", code == 0 and (app / "deps" / "@alice" / "json-kit" / "pudu.toml").exists(), out)

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

        secret = repository("alice", "secret-kit", private=True)
        write(secret / "pudu.toml", '[package]\nname = "@alice/secret-kit"\nversion = "0.1.0"\n')
        write(secret / "src" / "SecretKit" / "Core.pudu", "module SecretKit.Core\n\nexport fn two() -> Int {\n  2\n}\n")
        git(secret, "add", "-A")
        git(secret, "commit", "-qm", "one")
        git(secret, "push", "-q", "origin", "main")
        code, out = run(["release", "0.1.0"], secret)
        check("a private repository's release is published", code == 0, out)
        other = work / "other"
        write(other / "pudu.toml", '[package]\nname = "other"\n')
        code, out = run(["install", "@alice/secret-kit@0.1.0"], other)
        check("its owner installs a private package", code == 0, out)
        stranger = work / "stranger"
        write(stranger / "pudu.toml", '[package]\nname = "stranger"\n')
        code, out = run(["install", "@alice/secret-kit@0.1.0"], stranger, {"PUDU_TOKEN": "gho_bob"})
        check("a private package does not exist to an account that cannot read it", code != 0 and "is not a project" in out, out)

        checksum = [line for line in (app / "pudu.lock").read_text().splitlines() if line.startswith("checksum")][0].split("sha256:")[1].strip('"')
        cache = work / "home" / "cache"
        shutil.rmtree(cache / "releases" / f"sha256-{checksum}")
        with open(cache / "archives" / f"sha256-{checksum}.tar.gz", "ab") as damaged:
            damaged.write(b"x")
        shutil.rmtree(app / "deps")
        code, out = run(["install"], app)
        check("a damaged cached archive is downloaded again", code == 0 and (app / "deps" / "@alice" / "json-kit").exists(), out)

        GitHub.repositories[("alice", "evil-kit")] = {"bare": "", "private": False}
        releases = url + "/api/v1/packages/@alice/evil-kit/releases"
        for case, label in [("link", "a symbolic link"), ("hardlink", "a hard link"), ("parent", "a parent path"), ("duplicate", "a duplicate path"), ("std", "a Std root"), ("other", "another package's manifest"), ("bomb", "an archive past the unpacked limit")]:
            status, body = call("POST", releases, json.dumps({"version": "1.0.0", "tag": "v" + case}).encode(), {"Authorization": "Bearer gho_alice", "Content-Type": "application/json"})
            check(f"the registry refuses a commit with {label}", status in (409, 422), f"{status} {body[:200]!r}")
        status, _ = call("GET", url + "/api/v1/packages/@alice/json-kit/releases/1.0.0/files/../../../../etc/passwd")
        check("a file outside a release is not served", status == 404, str(status))
        status, body = call("GET", url + "/api/v1/packages/@alice/json-kit")
        document = json.loads(body)
        check("a release records the commit it came from", all(len(r.get("commit", "")) == 40 for r in document["releases"]), body[:300])
        for release in document["releases"]:
            status, archive = call("GET", url + f"/api/v1/packages/@alice/json-kit/releases/{release['version']}/archive")
            check(f"release {release['version']}'s archive has the digest its document records", status == 200 and "sha256:" + hashlib.sha256(archive).hexdigest() == release["checksum"])
        status, body = call("GET", url + "/api/v1/handles/@alice")
        check("a handle's profile comes from GitHub", status == 200 and b"https://avatars.example/alice" in body, body[:200])
        status, _ = call("POST", url + "/api/v1/packages/@alice/json-kit/releases", json.dumps({"version": "9.0.0"}).encode(), {"Authorization": "Bearer gho_forged", "Content-Type": "application/json"})
        check("a token GitHub refuses may not publish", status == 401, str(status))

        snapshot = pathlib.Path(arguments.snapshot).resolve() if arguments.snapshot else work / "snapshot"
        done = subprocess.run(["node", str(ROOT / "website" / "scripts" / "generate-packages.mjs"), "--registry", url, "--out", str(snapshot), "--pudu", pudu], env=environment, capture_output=True, text=True, timeout=300)
        catalogue = snapshot / "docs" / "@alice" / "json-kit.json"
        written = json.loads((snapshot / "packages.json").read_text()) if (snapshot / "packages.json").exists() else {}
        check("the website's package data is written from the registry", done.returncode == 0 and [p["name"] for p in written.get("projects", [])] == ["@alice/json-kit"], done.stdout + done.stderr)
        check("it carries the latest release's files and API catalogue", (snapshot / "files" / "@alice" / "json-kit" / "2.0.0" / "src" / "JsonKit" / "Value.pudu").exists() and catalogue.exists() and "textOf" in catalogue.read_text(), done.stderr)

        code, out = run(["logout"], lib)
        check("logout forgets the token", code == 0 and "signed out" in out, out)
        code, out = run(["whoami"], lib)
        check("after logout there is no account", code != 0 and "not signed in" in out, out)
    finally:
        server.terminate()
        server.wait(timeout=10)
        stand_in.shutdown()
        if not arguments.keep:
            shutil.rmtree(work, ignore_errors=True)
    if FAILURES:
        print(f"\n{len(FAILURES)} failed")
        sys.exit(1)
    print("\nall registry checks passed")


if __name__ == "__main__":
    main()
