#!/usr/bin/env python3
"""Platform strip policy and packaging refusal contracts."""
import argparse
from contextlib import redirect_stderr
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
SPEC = importlib.util.spec_from_file_location("package_binary", ROOT / "scripts" / "package-binary.py")
package_binary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package_binary)


class PackageBinaryStrip(unittest.TestCase):
  def test_macos_preserves_loader_symbols_without_unused_globals(self):
    executable = Path("staged package/bin/pudu")
    with patch.object(package_binary.sys, "platform", "darwin"), \
         patch.object(package_binary.shutil, "which", return_value="/usr/bin/strip"), \
         patch.object(package_binary.subprocess, "run") as run:
      package_binary.strip(executable, argparse.ArgumentParser())
    run.assert_called_once_with(["/usr/bin/strip", "-u", "-r", str(executable)], check=True)

  def test_linux_retains_the_platform_default(self):
    executable = Path("stage/bin/pudu")
    with patch.object(package_binary.sys, "platform", "linux"), \
         patch.object(package_binary.shutil, "which", return_value="/usr/bin/strip"), \
         patch.object(package_binary.subprocess, "run") as run:
      package_binary.strip(executable, argparse.ArgumentParser())
    run.assert_called_once_with(["/usr/bin/strip", str(executable)], check=True)

  def test_windows_executable_skips_strip(self):
    with patch.object(package_binary.sys, "platform", "win32"), \
         patch.object(package_binary.shutil, "which") as which, \
         patch.object(package_binary.subprocess, "run") as run:
      package_binary.strip(Path("stage/bin/pudu.exe"), argparse.ArgumentParser())
    which.assert_not_called()
    run.assert_not_called()

  def test_missing_strip_refuses_with_the_packaging_diagnostic(self):
    parser = argparse.ArgumentParser(prog="package-binary")
    stderr = io.StringIO()
    with patch.object(package_binary.shutil, "which", return_value=None), \
         patch.object(package_binary.subprocess, "run") as run, \
         redirect_stderr(stderr), self.assertRaises(SystemExit) as failure:
      package_binary.strip(Path("stage/bin/pudu"), parser)
    self.assertEqual(failure.exception.code, 2)
    self.assertEqual(stderr.getvalue().splitlines()[-1],
      "package-binary: error: strip is required to package the executable")
    run.assert_not_called()

  def test_strip_failure_propagates(self):
    failure = subprocess.CalledProcessError(1, ["strip"])
    with patch.object(package_binary.shutil, "which", return_value="/usr/bin/strip"), \
         patch.object(package_binary.subprocess, "run", side_effect=failure), \
         self.assertRaises(subprocess.CalledProcessError) as caught:
      package_binary.strip(Path("stage/bin/pudu"), argparse.ArgumentParser())
    self.assertIs(caught.exception, failure)


if __name__ == "__main__":
  unittest.main()
