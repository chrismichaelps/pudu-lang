#!/usr/bin/env python3
"""A streaming reader holds as much at ten times the input as it does at one.

This cannot be checked from inside the language: what is under test is how
much memory the whole process reaches, and a program cannot see its own peak.
So each reader runs in a separate process on a small file and on a file ten
times larger, and the peaks are compared.

The buffered reader is run too, as a control. It holds every line, so its peak
must grow with the input; if it does not, the measurement is not seeing memory
at all and a flat streaming result would prove nothing.

Usage: python3 test/residency.py [path-to-pudu]
"""

import json
import os
import subprocess
import sys
import tempfile

executable = sys.argv[1] if len(sys.argv) > 1 else "pudu"

LINE = b"2026-09-14T10:00:00Z,sensor-0042,21.375,ok,the quick brown fox jumps over the lazy dog\n"
JSON_LINE = b'{"at":"2026-09-14T10:00:00Z","sensor":"sensor-0042","value":21.375,"ok":true,"note":"the quick brown fox"}\n'
SMALL_MEGABYTES = 2
LARGE_MEGABYTES = 20

# A streaming peak may rise a little with the input — a larger file's last
# chunk, allocator rounding — but not in proportion to it.
STREAMING_RATIO = 1.25
STREAMING_SLACK_BYTES = 8 * 1024 * 1024
# The control holds every line, so its peak must rise by at least the extra
# input. A ratio of peaks would instead depend on how much of the peak is the
# runtime itself, and on how compactly the held lines are stored.

# Runs one child and reports only that child's peak: a wrapper process has
# exactly one child, so its children's peak is the program's own.
MEASURE = (
    "import resource, subprocess, sys\n"
    "done = subprocess.run(sys.argv[1:], capture_output=True)\n"
    "sys.stdout.buffer.write(done.stdout)\n"
    "sys.stdout.buffer.write(done.stderr)\n"
    "print('PEAK', resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)\n"
    "sys.exit(done.returncode)\n"
)

# macOS reports the peak in bytes and Linux in kilobytes.
PEAK_UNIT = 1 if sys.platform == "darwin" else 1024

PROBES = {
    "foldLines": """  match Io.foldLines(path, 0, fn(count: Int, line: Str) -> Int { count + 1 }) {
    case Ok(count) => {
      let _w = Io.writeLine("counted " + show(count))
      0
    }
    case Err(_) => 2
  }""",
    "countBytes": """  match Io.countBytes(path) {
    case Ok(total) => {
      let _w = Io.writeLine("counted " + show(total))
      0
    }
    case Err(_) => 2
  }""",
    "foldRows": """  match Csv.foldRows(path, 0, fn(count: Int, _row: Array[Str]) -> Int { count + 1 }) {
    case Ok(count) => {
      let _w = Io.writeLine("counted " + show(count))
      0
    }
    case Err(_) => 2
  }""",
    "jsonFoldLines": """  match Json.foldLines(path, 0, fn(count: Int, _value: Json.Json) -> Int { count + 1 }) {
    case Ok(count) => {
      let _w = Io.writeLine("counted " + show(count))
      0
    }
    case Err(_) => 2
  }""",
    "readAllLinesOf": """  match Io.readAllLinesOf(path) {
    case Ok(lines) => {
      let _w = Io.writeLine("counted " + show(lines.length()))
      0
    }
    case Err(_) => 2
  }""",
}


def write_input(path, megabytes, line):
    lines = megabytes * 1024 * 1024 // len(line)
    with open(path, "wb") as out:
        block = line * 1000
        for _ in range(lines // 1000):
            out.write(block)
        out.write(line * (lines % 1000))
    return lines, lines * len(line)


def program(reader, data_path):
    return (
        "module Probe\n\nimport Std.Csv as Csv\nimport Std.Io as Io\nimport Std.Json as Json\n\nexport fn main() -> Int {\n"
        f'  let path = "{data_path}"\n'
        f"{PROBES[reader]}\n}}\n"
    )


def measure(directory, reader, data_path):
    source = os.path.join(directory, f"{reader}-{os.path.basename(data_path)}", "Probe.pudu")
    os.makedirs(os.path.dirname(source), exist_ok=True)
    with open(source, "w") as out:
        out.write(program(reader, data_path))
    done = subprocess.run(
        [sys.executable, "-c", MEASURE, executable, "run", source],
        capture_output=True,
        text=True,
    )
    counted = None
    peak = None
    for line in done.stdout.splitlines():
        if line.startswith("counted "):
            counted = int(line.split()[1])
        elif line.startswith("PEAK "):
            peak = int(line.split()[1]) * PEAK_UNIT
    if done.returncode != 0 or counted is None or peak is None:
        raise SystemExit(f"residency: {reader} on {os.path.basename(data_path)} did not run:\n{done.stdout}")
    return counted, peak


def main():
    failures = []
    report = {}
    with tempfile.TemporaryDirectory(prefix="pudu-residency-") as directory:
        small = os.path.join(directory, "small.txt")
        large = os.path.join(directory, "large.txt")
        small_lines, small_bytes = write_input(small, SMALL_MEGABYTES, LINE)
        large_lines, large_bytes = write_input(large, LARGE_MEGABYTES, LINE)
        # JSON Lines needs a value on every line, so its reader gets its own
        # files of the same sizes.
        small_json = os.path.join(directory, "small.jsonl")
        large_json = os.path.join(directory, "large.jsonl")
        small_json_lines, _ = write_input(small_json, SMALL_MEGABYTES, JSON_LINE)
        large_json_lines, _ = write_input(large_json, LARGE_MEGABYTES, JSON_LINE)
        expected = {
            "foldLines": (small_lines, large_lines),
            "countBytes": (small_bytes, large_bytes),
            "foldRows": (small_lines, large_lines),
            "jsonFoldLines": (small_json_lines, large_json_lines),
            "readAllLinesOf": (small_lines, large_lines),
        }
        inputs = {"jsonFoldLines": (small_json, large_json)}
        for reader in PROBES:
            small_path, large_path = inputs.get(reader, (small, large))
            small_count, small_peak = measure(directory, reader, small_path)
            large_count, large_peak = measure(directory, reader, large_path)
            report[reader] = {
                "smallMegabytes": round(small_peak / 1048576),
                "largeMegabytes": round(large_peak / 1048576),
            }
            if (small_count, large_count) != expected[reader]:
                failures.append(
                    f"{reader} counted {(small_count, large_count)}, expected {expected[reader]}"
                )
            if reader == "readAllLinesOf":
                if large_peak - small_peak < large_bytes - small_bytes:
                    failures.append(
                        f"the buffered control did not grow ({small_peak} -> {large_peak} bytes), "
                        "so the measurement cannot see memory"
                    )
            elif large_peak > small_peak * STREAMING_RATIO + STREAMING_SLACK_BYTES:
                failures.append(
                    f"{reader} held {small_peak} bytes at {SMALL_MEGABYTES} MB "
                    f"but {large_peak} at {LARGE_MEGABYTES} MB"
                )

    if failures:
        print("residency: a streaming reader must not hold its input.\n", file=sys.stderr)
        for failure in failures:
            print("  " + failure + "\n", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(report, sort_keys=True))


main()
