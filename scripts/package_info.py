import json
import re


def load_package(root, requested=None, *, allow_series_change=False):
  root = root.resolve(strict=True)
  if requested is None:
    selected = re.search(r"^packages:\s*(\S+)", (root / "cabal.project").read_text(), re.MULTILINE)
    if selected is None:
      raise ValueError("no selected package in cabal.project")
    requested = selected[1]
  package = (root / requested).resolve(strict=True)
  if package.parent != (root / "packages/pudu").resolve():
    raise ValueError("versioned packages must be directly inside packages/pudu")
  if not re.fullmatch(r"v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", package.name):
    raise ValueError("package directory must name a canonical version series such as v0.1")
  configuration = json.loads((package / "toolchain.json").read_text())
  if not isinstance(configuration, dict):
    raise ValueError("package toolchain must be an object")
  if configuration.get("schema") != 1:
    raise ValueError("unsupported package toolchain schema")
  backend = configuration.get("backend")
  if not isinstance(backend, str) or not backend:
    raise ValueError("package backend is missing")
  source = configuration["versionSource"]
  if not isinstance(source, dict) or not isinstance(source.get("file"), str) or not source["file"]:
    raise ValueError("versionSource must identify a version file")
  version_path = (package / source["file"]).resolve(strict=True)
  if not version_path.is_relative_to(package):
    raise ValueError("version source must be inside its package")
  contents = version_path.read_text().strip()
  if source["format"] == "cabal":
    versions = re.findall(r"^version:\s*(\S+)", contents, re.MULTILINE)
    if len(versions) != 1:
      raise ValueError("Cabal manifest must declare exactly one version")
    version = versions[0]
  elif source["format"] == "text":
    version = contents
  else:
    raise ValueError("unsupported version source format")
  if not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", version):
    raise ValueError("package version must have three numeric components without leading zeros")
  expected = "v" + ".".join(version.split(".")[:2])
  if not allow_series_change and package.name != expected:
    raise ValueError(f"package version {version} does not match directory {package.name}")
  for key in ("build", "locateBinary"):
    command = configuration.get(key)
    if not isinstance(command, list) or not command or not all(isinstance(arg, str) and arg for arg in command):
      raise ValueError(f"{key} must be a nonempty command argument array")
  for required in ("lib/Std", "LICENSE"):
    if not (package / required).exists():
      raise ValueError(f"package is missing {required}")
  return package, version, configuration
