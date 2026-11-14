"""Exercise installation configuration and PATH verification without building a compiler."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def executable(path, source):
    path.write_text(source)
    path.chmod(0o755)


with tempfile.TemporaryDirectory(prefix="pudu-refresh-") as temporary:
    scratch = Path(temporary)
    commands = scratch / "commands"
    commands.mkdir()
    for name in ("bash", "dirname", "mkdir", "awk", "cmp", "cat"):
        (commands / name).symlink_to(shutil.which(name))
    python = shutil.which("python3")
    prelude = f"#!{python}\nimport json, os, sys\nfrom pathlib import Path\n"
    record = 'with open(os.environ["REFRESH_LOG"], "a") as log: log.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]]) + "\\n")\n'
    template = scratch / "compiler-template"
    executable(template, prelude + record + 'if sys.argv[1:] == ["repl"]: sys.stdin.read()\n')
    executable(commands / "node", prelude + record)
    executable(commands / "cabal", prelude + record + '''
if sys.argv[1] == os.environ.get("REFRESH_FAIL"):
    sys.exit(23)
if sys.argv[1] == "install":
    import shutil
    directory = next(arg.split("=", 1)[1] for arg in sys.argv if arg.startswith("--installdir="))
    shutil.copy2(os.environ["REFRESH_TEMPLATE"], Path(directory) / "pudu")
''')

    def run(name, *, failure="", shadow=""):
        case = scratch / name
        install = case / "install with spaces"
        install.mkdir(parents=True)
        log = case / "commands.jsonl"
        path = [str(install), str(commands)]
        if shadow:
            earlier = case / "earlier"
            earlier.mkdir()
            if shadow == "equal":
                shutil.copy2(template, earlier / "pudu")
            else:
                executable(earlier / "pudu", prelude + 'sys.exit(99)\n')
            path.insert(0, str(earlier))
        environment = {
            **os.environ,
            "PATH": os.pathsep.join(path),
            "REFRESH_LOG": str(log),
            "REFRESH_TEMPLATE": str(template),
            "REFRESH_FAIL": failure,
        }
        result = subprocess.run(
            [shutil.which("bash"), str(ROOT / "scripts/refresh-install.sh"), str(install)],
            env=environment, capture_output=True, text=True, timeout=20,
        )
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result, calls, install

    for name, shadow in (("normal", ""), ("identical", "equal")):
        result, calls, install = run(name, shadow=shadow)
        assert result.returncode == 0, result.stdout + result.stderr
        assert calls[0] == ["cabal", "build", "exe:pudu", "--enable-optimization=2"]
        assert calls[1] == ["cabal", "install", "exe:pudu", "--enable-optimization=2",
                            f"--installdir={install}", "--overwrite-policy=always"]
        assert calls[2:5] == [["pudu", "version"],
                              ["pudu", "check", str(ROOT / "test-fixtures/tooling/RecentLanguage.pudu")],
                              ["pudu", "repl"]]
        expected = install if not shadow else install.parent / "earlier"
        assert calls[5] == ["node", str(ROOT / "test/lsp-session.mjs"), str(expected / "pudu")]
        assert len(calls) == 6

    result, calls, _ = run("shadowed", shadow="different")
    assert result.returncode == 1
    assert "comes before" in result.stderr
    assert len(calls) == 2

    for operation, count in (("build", 1), ("install", 2)):
        result, calls, _ = run(f"failed-{operation}", failure=operation)
        assert result.returncode == 23, result.stdout + result.stderr
        assert len(calls) == count

print("optimized refresh, exact executable checks, PATH shadowing and failures passed")
