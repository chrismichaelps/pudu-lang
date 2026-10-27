import argparse
import json
import math
import os
from pathlib import Path
import random
import statistics
import struct
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("binary")
parser.add_argument("--bench", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
binary = str(Path(args.binary).resolve())
env = dict(os.environ, PUDU_LIB=str(root / "packages/pudu/v0.1/lib"))


def bits(value):
    return struct.unpack(">Q", struct.pack(">d", value))[0]


values = [1e300, 1e-300, math.ulp(0.0), sys.float_info.min, sys.float_info.max,
          math.nextafter(sys.float_info.min, 0.0), 1.0, 4.0, 9.0]
exponents = set(range(-1074, 1024, 31)) | {2, 4, 8, 16, 32, 64, 128, 256, 512}
exponents |= {-value for value in tuple(exponents) if value > 0}
for exponent in sorted(exponents):
    value = math.ldexp(1.0, exponent)
    values.extend([math.nextafter(value, 0.0), value, math.nextafter(value, math.inf)])
randomizer = random.Random(661)
for _ in range(400):
    values.append(struct.unpack(">d", struct.pack(">Q", randomizer.getrandbits(63)))[0])
values = list(dict.fromkeys(value for value in values if value > 0.0 and math.isfinite(value)))
program = "module SqrtRange\nimport Std.Math.Float as Float\nexport fn main() -> Int {\n"
program += "  let inputs = [" + ", ".join(repr(value) for value in values) + "]\n"
program += """  for value in inputs {
    match Float.sqrt(value) {
      case Some(found) => print(show(found))
      case None => print("missing")
    }
  }
  let infinity = 1.0 / 0.0
  print(show(Float.sqrt(-1.0)))
  print(show(Float.sqrt(-infinity)))
  print(show(Float.sqrt(infinity - infinity)))
  print(show(Float.sqrt(infinity)))
  print(show(Float.sqrt(0.0)))
  print(show(Float.sqrt(-0.0)))
  0
}
"""
with tempfile.TemporaryDirectory(prefix="pudu-sqrt-range-") as scratch:
    path = Path(scratch) / "SqrtRange.pudu"
    path.write_text(program)
    result = subprocess.run([binary, "run", str(path)], env=env, capture_output=True, text=True, timeout=90)
    assert result.returncode == 0, result.stderr
    lines = result.stdout.splitlines()
    assert len(lines) == len(values) + 6, result.stdout[-300:]
    for value, rendered in zip(values, lines):
        actual, expected = float(rendered), math.sqrt(value)
        distance = abs(bits(actual) - bits(expected))
        assert math.isfinite(actual) and distance == 0, (value, actual, expected, distance)
    domain = lines[len(values):]
    assert domain[:3] == ["None", "None", "None"], domain
    assert domain[3].startswith("Some(") and math.isinf(float(domain[3][5:-1])), domain
    assert domain[4] == "Some(0.0)" and domain[5] == "Some(-0.0)", domain
kernels = """module FloatKernels
import Std.Math.Float as Float
fn bits(value: Float) -> Str { show(Float.toBits(value)) }
export fn main() -> Int {
  let tiny = Float.fromBits(1u64)
  print(bits(Float.floor(-0.0)) + " " + bits(Float.ceil(-0.5)) + " " + bits(Float.trunc(-0.7)))
  print(show(Float.round(2.5)) + " " + show(Float.round(-2.5)) + " " + show(Float.round(0.49999999999999994)))
  print(show(Float.floor(-3.2)) + " " + show(Float.ceil(3.2)) + " " + show(Float.trunc(4503599627370497.0)))
  print(bits(Float.fma(0.1, 10.0, -1.0)) + " " + bits(0.1 * 10.0 - 1.0))
  print(bits(Float.fromBits(Float.toBits(-0.0))) + " " + show(tiny > 0.0) + " " + bits(tiny))
  print(show(Float.asin(1.5)) + " " + show(Float.ln(0.0)) + " " + show(Float.powf(-8.0, 0.5)))
  print(show(Float.powf(0.0, -1.0)) + " " + show(Float.powf(-2.0, 3.0)) + " " + show(Float.log2(8.0)))
  print(show(Float.atan2(0.0, -1.0) == Float.pi()) + " " + show(Float.hypot(3e300, 4e300)))
  0
}
"""
refused = "module Refused\nexport fn main() -> Int {\n  let root = floatSqrt(4)\n  0\n}\n"
with tempfile.TemporaryDirectory(prefix="pudu-float-kernels-") as scratch:
    path = Path(scratch) / "FloatKernels.pudu"
    path.write_text(kernels)
    result = subprocess.run([binary, "run", str(path)], env=env, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stderr
    negative_zero = str(bits(-0.0))
    expected = [
        f"{negative_zero} {negative_zero} {negative_zero}",
        "3.0 -3.0 0.0",
        "-4.0 4.0 4.503599627370497e15",
        f"{bits(5.551115123125783e-17)} {bits(0.1 * 10.0 - 1.0)}",
        f"{negative_zero} true 1",
        "None None None",
        "None Some(-8.0) Some(3.0)",
        "true 5.0e300",
    ]
    assert result.stdout.splitlines() == expected, result.stdout
    path = Path(scratch) / "Refused.pudu"
    path.write_text(refused)
    result = subprocess.run([binary, "check", str(path)], env=env, capture_output=True, text=True, timeout=60)
    assert result.returncode != 0 and "error[" in result.stdout + result.stderr, result.stdout + result.stderr

existing = subprocess.run([binary, "run", str(root / "test-fixtures/stdlib/UsesFloatMath.pudu")], env=env,
                          capture_output=True, text=True, timeout=60)
assert existing.returncode == 20, (existing.returncode, existing.stderr)
subprocess.run([binary, "fmt", "--check", str(root / "packages/pudu/v0.1/lib/Std/Math/Float.pudu"),
                str(root / "bench/RootKernels.pudu")], check=True, env=env, capture_output=True, text=True)
print(f"sqrt: {len(values)} golden cases correctly rounded; kernel contracts, type refusal, domains and 20 Float math checks passed")

if args.bench:
    measured = subprocess.run([binary, "run", str(root / "bench/RootKernels.pudu")], env=env,
                              capture_output=True, text=True, check=True, timeout=180)
    times, errors = {}, {}
    for line in measured.stdout.splitlines():
        kind, name, value, answer = line.split()
        if kind == "timing":
            assert float(answer) > 0.0
            times.setdefault(name, []).append(int(value))
        elif kind == "accuracy":
            value, answer = float(value), float(answer)
            relative = abs(answer * math.sqrt(value) - 1.0)
            errors[name] = max(errors.get(name, 0.0), relative)
        else:
            raise AssertionError(line)
    assert set(times) == {"root", "estimate1", "estimate2"} and all(len(samples) == 5 for samples in times.values())
    print(json.dumps({"batch": 2000, "times_ms": times,
                      "median_ms": {name: statistics.median(samples) for name, samples in times.items()},
                      "sampled_max_relative_error": errors}, sort_keys=True))
