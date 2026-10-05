#!/usr/bin/env python3
"""Exercise atomic filesystem permissions through the public Pudu APIs."""

import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


def mode(path):
    return stat.S_IMODE(path.stat().st_mode)


def check(executable, mask):
    with tempfile.TemporaryDirectory(prefix="pudu-atomic-") as workspace:
        root = Path(workspace)
        statements = []
        expected = {}
        for api in ("text", "bytes"):
            for permission in (None, 0o640, 0o600, 0o755):
                target = root / f"{api}-{permission}"
                if permission is not None:
                    target.write_bytes(b"old")
                    target.chmod(permission)
                path = json.dumps(str(target))
                call = (f'Fs.writeTextAtomically({path}, "complete")' if api == "text"
                        else f'Fs.writeAtomically({path}, &Bytes.fromText("complete"))')
                statements.append(f'  print(show({call} == Ok(())))')
                expected[target] = permission
        ordinary = root / "ordinary"
        statements.append(f'  print(show(Io.write({json.dumps(str(ordinary))}, "complete") == Ok(())))')
        protected = root / "protected"
        protected.write_bytes(b"untouched")
        protected.chmod(0o640)
        linked = root / "linked"
        linked.symlink_to(protected)
        dangling = root / "dangling"
        dangling.symlink_to(root / "absent")
        for target in (linked, dangling):
            statements.append(f'  print(show(Fs.writeTextAtomically({json.dumps(str(target))}, "complete") == Ok(())))')
            expected[target] = 0o640 if target == linked else None
        blocked = root / "blocked"
        blocked.mkdir()
        (blocked / "retained").write_bytes(b"keep")
        for target in (blocked, root / "missing" / "child"):
            refusal = 'Err(Fs.Failed(Io.NotFound(_)))' if target != blocked else 'Err(_)'
            statements.extend([
                f'  match Fs.writeTextAtomically({json.dumps(str(target))}, "refused") {{',
                f'    case {refusal} => print("true")',
                '    case _ => print("false")',
                '  }',
            ])
        statements.extend([
            f'  match Fs.temporaryFileIn({json.dumps(str(root))}, "scratch-") {{',
            '    case Ok(path) => print(path)',
            '    case Err(_) => print("failed scratch")',
            '  }',
            '  0',
        ])
        source = root / "Main.pudu"
        source.write_text("module Main\n\nimport Std.Bytes as Bytes\nimport Std.Fs as Fs\nimport Std.Io as Io\n\nexport fn main() -> Int {\n" + "\n".join(statements) + "\n}\n")
        result = subprocess.run(
            ["sh", "-c", 'umask "$1"; exec "$2" run "$3"', "atomic-permissions",
             format(mask, "03o"), executable, str(source)],
            capture_output=True, text=True, check=False,
        )
        assert result.returncode == 0, f"Pudu exited {result.returncode}:\n{result.stdout}\n{result.stderr}"
        lines = result.stdout.splitlines()
        assert len(lines) == 14 and lines[:-1] == ["true"] * 13, (result.stdout, result.stderr)
        for target, permission in expected.items():
            assert target.read_bytes() == b"complete", target
            assert not target.is_symlink(), target
            assert mode(target) == (mode(ordinary) if permission is None else permission), (target, oct(mode(target)))
        assert mode(ordinary) == 0o666 & ~mask
        assert protected.read_bytes() == b"untouched" and mode(protected) == 0o640
        assert (blocked / "retained").read_bytes() == b"keep"
        assert not (root / "absent").exists() and not (root / "missing").exists()
        scratch = Path(lines[-1])
        assert scratch.parent == root and scratch.name.startswith("scratch-")
        assert scratch.read_bytes() == b"" and mode(scratch) == 0o600
        assert not any(path.name.startswith(".") for path in root.iterdir()), list(root.iterdir())


if __name__ == "__main__":
    if os.name != "posix":
        print("atomic POSIX permission checks skipped on this platform")
    else:
        pudu = str(Path(sys.argv[1]).resolve())
        for child_mask in (0o022, 0o077):
            check(pudu, child_mask)
        print("atomic byte/text creation, replacement, scratch and refusal checks passed")
