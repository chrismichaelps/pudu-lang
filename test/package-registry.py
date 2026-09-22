#!/usr/bin/env python3
"""End-to-end checks of `pudu` packages through git and a stand-in GitHub.

Packages live in bare git repositories under a temporary directory, reached as
`PUDU_GITHUB_URL=file://…/github`, so resolution, fetching, and releases run
real git. A stand-in for the GitHub REST API (`PUDU_GITHUB_API`) answers what
`pudu login`, `pudu release`, `pudu search`, and the website's package
snapshot ask: the account behind a token, repository topics, releases, search
by topic, tags, file contents, commits, and commit archives.

    python3 test/package-registry.py --pudu "$(cabal list-bin exe:pudu)"
"""

import argparse
import base64
import http.server
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import urllib.parse

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


class GitHub(http.server.BaseHTTPRequestHandler):
    """The part of the GitHub REST API that pudu and the website use."""

    root = None
    topics = {}
    releases = {}

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

    def bare(self, owner, name):
        path = GitHub.root / owner / name
        return path if path.is_dir() else None

    def git(self, bare, *args):
        return subprocess.run(["git", "--git-dir", str(bare), *args], capture_output=True)

    def repository(self, owner, name):
        return {
            "name": name, "full_name": f"{owner}/{name}", "owner": {"login": owner}, "private": False, "archived": False,
            "description": "From GitHub", "topics": GitHub.topics.get((owner, name), []), "html_url": f"https://github.com/{owner}/{name}",
            "stargazers_count": 7, "forks_count": 1, "open_issues_count": 2, "created_at": "2026-09-01T00:00:00Z",
            "license": {"spdx_id": "MIT"},
        }

    def body(self):
        length = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(length) or b"{}")

    def do_PUT(self):
        parts = urllib.parse.urlparse(self.path).path.strip("/").split("/")
        if len(parts) == 4 and parts[0] == "repos" and parts[3] == "topics":
            if self.login() != parts[1]:
                return self.answer(403, {"message": "Must have admin rights to Repository."})
            GitHub.topics[(parts[1], parts[2])] = self.body()["names"]
            return self.answer(200, {"names": GitHub.topics[(parts[1], parts[2])]})
        self.answer(404, {"message": "Not Found"})

    def do_POST(self):
        parts = urllib.parse.urlparse(self.path).path.strip("/").split("/")
        if len(parts) == 4 and parts[0] == "repos" and parts[3] == "releases":
            if self.login() != parts[1]:
                return self.answer(403, {"message": "Resource not accessible"})
            wanted = self.body()
            listed = GitHub.releases.setdefault((parts[1], parts[2]), [])
            if any(r["tag_name"] == wanted["tag_name"] for r in listed):
                return self.answer(422, {"message": "Validation Failed"})
            listed.append({"tag_name": wanted["tag_name"], "name": wanted.get("name", ""), "body": wanted.get("body", ""), "published_at": "2026-09-20T12:00:00Z", "author": {"login": parts[1]}})
            return self.answer(201, listed[-1])
        self.answer(404, {"message": "Not Found"})

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        parts = parsed.path.strip("/").split("/")
        page = int(query.get("page", ["1"])[0])
        if parsed.path == "/user":
            login = self.login()
            return self.answer(200, {"login": login}) if login else self.answer(401, {"message": "Bad credentials"})
        if parts[0] == "users" and len(parts) == 2:
            return self.answer(200, {"login": parts[1], "name": parts[1].title(), "avatar_url": "", "html_url": f"https://github.com/{parts[1]}", "type": "User"})
        if parsed.path == "/search/repositories":
            words = query.get("q", [""])[0].split()
            topic = next((w.split(":", 1)[1] for w in words if w.startswith("topic:")), None)
            rest = [w for w in words if not w.startswith("topic:")]
            found = [self.repository(o, n) for (o, n), names in sorted(GitHub.topics.items()) if topic in names and all(w in n for w in rest)]
            return self.answer(200, {"total_count": len(found), "items": found if page == 1 else []})
        if parts[0] != "repos" or len(parts) < 3:
            return self.answer(404, {"message": "Not Found"})
        owner, name = parts[1], parts[2]
        bare = self.bare(owner, name)
        if bare is None:
            return self.answer(404, {"message": "Not Found"})
        if len(parts) == 4 and parts[3] == "topics":
            return self.answer(200, {"names": GitHub.topics.get((owner, name), [])})
        if len(parts) == 4 and parts[3] == "releases":
            return self.answer(200, GitHub.releases.get((owner, name), []) if page == 1 else [])
        if len(parts) == 4 and parts[3] == "tags":
            done = self.git(bare, "for-each-ref", "refs/tags", "--format=%(refname:strip=2) %(objectname) %(*objectname)")
            tags = []
            for line in done.stdout.decode().splitlines():
                fields = line.split()
                tags.append({"name": fields[0], "commit": {"sha": fields[2] if len(fields) > 2 else fields[1]}})
            return self.answer(200, tags if page == 1 else [])
        if len(parts) >= 5 and parts[3] == "contents":
            ref = query.get("ref", ["HEAD"])[0]
            done = self.git(bare, "show", f"{ref}:{'/'.join(parts[4:])}")
            return self.answer(200, {"content": base64.b64encode(done.stdout).decode(), "encoding": "base64"}) if done.returncode == 0 else self.answer(404, {"message": "Not Found"})
        if len(parts) == 5 and parts[3] == "commits":
            done = self.git(bare, "log", "-1", "--format=%cI", parts[4])
            return self.answer(200, {"sha": parts[4], "commit": {"committer": {"date": done.stdout.decode().strip()}}})
        if len(parts) == 5 and parts[3] == "tarball":
            done = self.git(bare, "archive", "--format=tar.gz", f"--prefix={owner}-{name}-{parts[4][:7]}/", parts[4])
            return self.answer(200, done.stdout, "application/x-gzip") if done.returncode == 0 else self.answer(404, {"message": "Not Found"})
        self.answer(404, {"message": "Not Found"})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pudu", required=True)
    parser.add_argument("--keep", action="store_true", help="keep the working directory")
    parser.add_argument("--snapshot", help="also write the website's package data here")
    arguments = parser.parse_args()
    pudu = os.path.abspath(arguments.pudu)
    work = pathlib.Path(tempfile.mkdtemp(prefix="pudu-packages-e2e-"))
    GitHub.root = work / "github"
    port = free_port()
    api = f"http://127.0.0.1:{port}"
    environment = dict(
        os.environ, PUDU_HOME=str(work / "home"), PUDU_GITHUB_URL=f"file://{GitHub.root}", PUDU_GITHUB_API=api, NO_COLOR="1",
        GIT_AUTHOR_NAME="a", GIT_AUTHOR_EMAIL="a@b", GIT_COMMITTER_NAME="a", GIT_COMMITTER_EMAIL="a@b",
    )
    for name in ["PUDU_TOKEN", "PUDU_MIN_RELEASE_AGE", "PUDU_GITHUB_CLIENT_ID", "GITHUB_TOKEN"]:
        environment.pop(name, None)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), GitHub)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    def run(args, cwd, extra=None):
        env = dict(environment, **(extra or {}))
        done = subprocess.run([pudu] + args, cwd=cwd, env=env, capture_output=True, text=True, timeout=300)
        return done.returncode, done.stdout + done.stderr

    def git(cwd, *args):
        return subprocess.run(["git", *args], cwd=cwd, env=environment, capture_output=True, text=True, check=True).stdout.strip()

    def repository(owner, name):
        bare = GitHub.root / owner / name
        bare.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True)
        clone = work / "clones" / name
        clone.mkdir(parents=True)
        git(clone, "init", "-q", "-b", "main")
        git(clone, "remote", "add", "origin", str(bare))
        return clone

    def library(root, version, name="@alice/json-kit"):
        write(root / "pudu.toml", f'[package]\nname = "{name}"\nversion = "{version}"\ndescription = "JSON helpers"\nkeywords = ["json"]\n')
        write(root / "src" / "JsonKit" / "Parse.pudu", "module JsonKit.Parse\n\n/// The number one, parsed.\nexport fn one() -> Int {\n  1\n}\n")
        write(root / "README.md", "# Json Kit\n\nParse and build JSON values.\n")
        git(root, "add", "-A")
        git(root, "commit", "-qm", f"version {version}")
        git(root, "push", "-q", "origin", "main")

    try:
        lib = repository("alice", "json-kit")
        library(lib, "1.0.0")
        code, out = run(["release", "1.0.0"], lib)
        check("release without a login tags and pushes, and says how to be listed", code == 0 and "tagged v1.0.0" in out and "pudu login" in out, out)
        code, out = run(["login", "--token", "gho_alice"], lib)
        check("login stores a GitHub token", code == 0 and "signed in to GitHub as @alice" in out, out)
        mode = oct((work / "home" / "credentials.toml").stat().st_mode & 0o777)
        check("the credentials file is private to its owner", mode == "0o600", mode)
        code, out = run(["whoami"], lib)
        check("whoami names the GitHub account", code == 0 and "@alice" in out, out)
        library(lib, "1.0.1")
        code, out = run(["release", "1.0.1", "--notes", "README.md"], lib)
        check("release creates the GitHub release and lists the package by topic", code == 0 and "created the GitHub release v1.0.1" in out and "pudu-package" in out, out)
        check("the repository carries the package topic", "pudu-package" in GitHub.topics.get(("alice", "json-kit"), []))
        code, out = run(["release", "1.0.1"], lib)
        check("releasing the same version again changes nothing", code == 0 and "created the GitHub release" not in out, out)
        manifest = (lib / "pudu.toml").read_text()
        (lib / "pudu.toml").write_text(manifest.replace('version = "1.0.1"', 'version = "1.0.2"'))
        code, out = run(["release", "1.0.2"], lib)
        check("a release refuses a working tree with changes", code != 0 and "not committed" in out, out)
        (lib / "pudu.toml").write_text(manifest)
        code, out = run(["search", "json"], lib)
        check("search finds the package by its topic", code == 0 and "@alice/json-kit" in out, out)

        app = work / "app"
        write(app / "pudu.toml", '[package]\nname = "app"\n')
        write(app / "src" / "Main.pudu", "module Main\n\nimport JsonKit.Parse as Parse\n\nexport fn main() -> Int {\n  Parse.one() - 1\n}\n")
        subprocess.run(["git", "-C", str(GitHub.root / "alice" / "json-kit"), "tag", "-f", "v9.9.9", git(lib, "rev-parse", "HEAD")], check=True, capture_output=True)
        code, out = run(["install", "@alice/json-kit"], app, {"PUDU_MIN_RELEASE_AGE": "999999"})
        check("a release younger than the minimum age is not chosen by a range", code != 0 and "minimum release age" in out, out)
        code, out = run(["install", "@alice/json-kit"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("a tag whose manifest gives another version is not a release", code == 0 and "+ @alice/json-kit 1.0.1" in out, out)
        lock = (app / "pudu.lock").read_text()
        check("the lock pins the repository commit and the tree digest", "github+file://" in lock and "#" in lock and 'checksum = "sha256:' in lock, lock)
        check("the manifest gains a caret requirement", '"@alice/json-kit" = "^1.0.1"' in (app / "pudu.toml").read_text())
        code, out = run(["run", "src/Main.pudu"], app)
        check("the installed module is imported by its name", code == 0, out)

        hidden = GitHub.root / "alice" / "json-kit.away"
        (GitHub.root / "alice" / "json-kit").rename(hidden)
        code, out = run(["install", "--verbose"], app)
        check("a lock and a warm cache install while GitHub is unreachable", code == 0 and "Already up to date" in out and "fetching" not in out, out)
        shutil.rmtree(app / "deps")
        code, out = run(["install", "--offline"], app)
        check("--offline restores deps/ from the cache", code == 0 and (app / "deps" / "@alice" / "json-kit" / "pudu.toml").exists(), out)
        hidden.rename(GitHub.root / "alice" / "json-kit")

        locked_commit = lock.split("#")[1].split('"')[0]
        write(lib / "src" / "JsonKit" / "Parse.pudu", "module JsonKit.Parse\n\nexport fn one() -> Int {\n  2\n}\n")
        git(lib, "commit", "-qam", "moved")
        git(lib, "tag", "-f", "v1.0.1")
        git(lib, "push", "-q", "-f", "origin", "main", "v1.0.1")
        shutil.rmtree(app / "deps")
        code, out = run(["install"], app)
        installed = (app / "deps" / "@alice" / "json-kit" / "src" / "JsonKit" / "Parse.pudu")
        check("a force-moved tag changes no locked build", code == 0 and locked_commit in (app / "pudu.lock").read_text() and installed.exists() and "  1\n" in installed.read_text(), out)

        git(lib, "reset", "-q", "--hard", "HEAD~1")
        git(lib, "push", "-q", "-f", "origin", "main")
        library(lib, "1.1.0")
        run(["release", "1.1.0"], lib)
        library(lib, "2.0.0")
        run(["release", "2.0.0"], lib)
        code, out = run(["update"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("update stays within the requirement", code == 0 and "1.0.1 → 1.1.0" in out, out)
        code, out = run(["upgrade"], app, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("upgrade raises the requirement and names the major version", code == 0 and "a new major version" in out and '"^2.0.0"' in (app / "pudu.toml").read_text(), out)
        git(lib, "push", "-q", "origin", ":refs/tags/v2.0.0")
        shutil.rmtree(work / "home" / "cache" / "checkouts")
        shutil.rmtree(app / "deps")
        code, out = run(["install"], app)
        check("a deleted tag still installs from the lock and the cached clone", code == 0 and (app / "deps" / "@alice" / "json-kit").exists(), out)
        fresh = work / "fresh"
        write(fresh / "pudu.toml", '[package]\nname = "fresh"\n')
        code, out = run(["install", "@alice/json-kit"], fresh, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("a new resolution does not choose a deleted tag", code == 0 and "+ @alice/json-kit 1.1.0" in out, out)
        code, out = run(["install", "@alice/json-kt"], fresh, {"PUDU_MIN_RELEASE_AGE": "0"})
        check("a repository that does not exist is named in the error", code != 0 and "json-kt" in out and "not a repository" in out, out)

        checkouts = work / "home" / "cache" / "checkouts"
        for parse in checkouts.glob("*/*/src/JsonKit/Parse.pudu"):
            parse.write_text(parse.read_text() + "// injected\n")
        shutil.rmtree(app / "deps")
        code, out = run(["install"], app)
        check("a damaged cached checkout is refused", code != 0 and "pudu.lock records" in out, out)

        snapshot = pathlib.Path(arguments.snapshot).resolve() if arguments.snapshot else work / "snapshot"
        done = subprocess.run(["node", str(ROOT / "website" / "scripts" / "generate-packages.mjs"), "--api", api, "--out", str(snapshot), "--pudu", pudu], env=environment, capture_output=True, text=True, timeout=300)
        written = json.loads((snapshot / "packages.json").read_text()) if (snapshot / "packages.json").exists() else {}
        projects = written.get("projects", [])
        check("the website's package data comes from the GitHub API", done.returncode == 0 and [p["name"] for p in projects] == ["@alice/json-kit"], done.stdout + done.stderr)
        latest = projects[0]["latest"] if projects else ""
        check("it carries the releases GitHub lists, newest last", latest == "1.1.0" and [r["version"] for r in projects[0]["releases"]] == ["1.0.0", "1.0.1", "1.1.0"], json.dumps(projects)[:400])
        docs = snapshot / "docs" / "@alice" / "json-kit.json"
        check("it carries the latest release's files and API catalogue", (snapshot / "files" / "@alice" / "json-kit" / latest / "src" / "JsonKit" / "Parse.pudu").exists() and docs.exists() and "one" in docs.read_text(), done.stderr)

        code, out = run(["logout"], lib)
        check("logout forgets the token", code == 0 and "signed out" in out, out)
        code, out = run(["whoami"], lib)
        check("after logout there is no account", code != 0 and "not signed in" in out, out)
    finally:
        server.shutdown()
        if not arguments.keep:
            shutil.rmtree(work, ignore_errors=True)
    if FAILURES:
        print(f"\n{len(FAILURES)} failed")
        sys.exit(1)
    print("\nall package checks passed")


if __name__ == "__main__":
    main()
