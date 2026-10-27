import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap


root = Path(__file__).resolve().parent.parent
workflow = (root / ".github/workflows/website-linux.yml").read_text()
configured = re.search(
    r"- name: Configure verified HTTPS Hackage transport\n        run: \|\n((?:          [^\n]*\n)+)",
    workflow,
)
assert configured, "workflow configuration step is absent"
command = textwrap.dedent(configured[1])
assert "cabal-update: false" in workflow[:configured.start()]
updates = list(re.finditer(r"- run: cabal update\s*\n", workflow))
assert len(updates) == 1 and updates[0].start() > configured.end()
subprocess.run(["bash", "-n", "-c", command], check=True)


def configure(path):
    subprocess.run(
        ["bash", "-eu", "-c", command],
        env=dict(os.environ, CABAL_CONFIG=str(path)),
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    contents = path.read_text()
    assert "url: https://hackage.haskell.org/" in contents
    assert "secure: True" in contents
    assert "url: http://hackage.haskell.org/" not in contents
    return contents


with tempfile.TemporaryDirectory(prefix="pudu-hackage-config-") as scratch:
    directory = Path(scratch)
    existing = directory / "existing"
    existing.write_text(
        "repository hackage.haskell.org\n  url: http://hackage.haskell.org/\n"
        "repository internal\n  url: https://packages.example.invalid/\n  secure: True\n"
        f"remote-repo-cache: {directory / 'cache'}\njobs: 3\n"
    )
    changed = configure(existing)
    assert "packages.example.invalid" not in changed
    assert changed.count("repository hackage.haskell.org") == 1
    assert "jobs: 3" in changed
    assert f"remote-repo-cache: {directory / 'cache'}" in changed
    assert configure(existing) == changed, "configuration is not idempotent"
    configure(directory / "missing")
    invalid = directory / "invalid"
    invalid.write_text("jobs: not-a-number\n")
    try:
        configure(invalid)
    except subprocess.CalledProcessError:
        assert invalid.read_text() == "jobs: not-a-number\n"
    else:
        raise AssertionError("malformed configuration was accepted")
print("Hackage HTTPS configuration, preservation, idempotence and missing config passed")
