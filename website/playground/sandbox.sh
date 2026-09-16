#!/usr/bin/env bash
# Run one playground program in isolation.
#
#   sandbox.sh --workdir DIR --program REL --compiler PUDU --library LIB \
#              --isolation bwrap|confined|none --memory-mb N --cpu-seconds N \
#              [--action run|fmt|lsp] --
#
# `run` compiles and runs the program, `fmt` writes it formatted to standard
# output, and `lsp` starts the language server with the program beside it, for
# the runner to ask one question of. All three read what a reader wrote, so all
# three are isolated alike.
#
# The playground runner calls this for every program and never runs one
# directly. It owns everything a program must not be able to do:
#
#   * reach the network, other processes, or the runner's environment and
#     files: under `bwrap` the program gets fresh user, network, process, IPC,
#     and host-name namespaces, a read-only view of the system, a private /tmp,
#     and an environment holding only what is set below;
#   * grow without bound: the runtime's heap is capped with GHCRTS, and CPU
#     time, file size, open files, and processes are capped with ulimit;
#   * outlive the runner's decision to stop it: this script `exec`s, so the
#     runner's signal reaches bubblewrap itself, and `--die-with-parent` takes
#     everything inside down with it.
#
# Every program is run with `pudu run --confined`, whatever the isolation: the
# runtime itself refuses files, programs, connections, and foreign calls, and
# keeps printing, the clock, and threads.
#
# The wall-clock deadline and the output bound are the runner's, because only
# the process reading the output can tell how much has been written.
#
# `--isolation confined` runs the program with the limits, an emptied
# environment, and the runtime's confinement, and no namespaces. It is for a
# host that cannot create namespaces and runs nothing else a program could
# reach — a serverless function, whose own credentials are in an environment
# the program never receives and in files the program cannot open.
#
# `--isolation none` is the same, named for a developer's own machine, where
# bubblewrap is usually unavailable. Neither is chosen unless asked for by name. When `bwrap`
# is asked for and cannot create its namespaces, the script exits 125 without
# running anything: a playground that cannot isolate a program says so rather
# than running it anyway.
set -euo pipefail

readonly REFUSED=125

refuse() {
  echo "sandbox: $*" >&2
  exit "$REFUSED"
}

workdir="" program="" compiler="" library="" isolation="" memory_mb="" cpu_seconds="" action="run"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workdir) workdir="$2"; shift 2 ;;
    --program) program="$2"; shift 2 ;;
    --compiler) compiler="$2"; shift 2 ;;
    --library) library="$2"; shift 2 ;;
    --isolation) isolation="$2"; shift 2 ;;
    --memory-mb) memory_mb="$2"; shift 2 ;;
    --cpu-seconds) cpu_seconds="$2"; shift 2 ;;
    --action) action="$2"; shift 2 ;;
    --) shift; break ;;
    *) refuse "unknown argument $1" ;;
  esac
done

[[ -d "$workdir" ]] || refuse "no work directory"
[[ "$program" =~ ^[A-Z][A-Za-z0-9_]*(/[A-Z][A-Za-z0-9_]*)*\.pudu$ ]] || refuse "the program path is not a module path"
[[ -f "$workdir/$program" ]] || refuse "no program at $program"
[[ "$memory_mb" =~ ^[1-9][0-9]*$ ]] || refuse "the memory bound is not a positive number"
[[ "$cpu_seconds" =~ ^[1-9][0-9]*$ ]] || refuse "the CPU bound is not a positive number"
case "$action" in
  run) command_line=(run --confined "$program") ;;
  fmt) command_line=(fmt --stdout "$program") ;;
  lsp) command_line=(lsp) ;;
  *) refuse "the action must be run, fmt, or lsp" ;;
esac
compiler="$(command -v "$compiler" 2>/dev/null)" || refuse "no compiler"
[[ -d "$library" ]] || refuse "no standard library at $library"
compiler="$(cd "$(dirname "$compiler")" && pwd -P)/$(basename "$compiler")"
library="$(cd "$library" && pwd -P)"

# Bounds every process started below inherits. The file bound is in blocks of
# 1024 bytes.
ulimit -t "$cpu_seconds"
ulimit -f 8192
ulimit -n 256
ulimit -c 0

heap="-M${memory_mb}m"

case "$isolation" in
  bwrap)
    command -v bwrap >/dev/null 2>&1 || refuse "bubblewrap is not installed"
    # Creating namespaces is what isolation is. A host that forbids it — a
    # container without user namespaces, a seccomp profile refusing unshare —
    # is found here, before the program is written anywhere it could run.
    bwrap --unshare-all --die-with-parent --ro-bind / / true >/dev/null 2>&1 \
      || refuse "bubblewrap cannot create namespaces on this host"

    # The process bound counts every process this user owns. In the runner's
    # container that is the runner and its programs; on a workstation it would
    # be the whole desktop, which is why it is set only here.
    ulimit -u 256

    binds=()
    for system in /usr /lib /lib64 /bin /sbin /etc/alternatives; do
      if [[ -e "$system" ]]; then binds+=(--ro-bind "$system" "$system"); fi
    done
    compiler_dir="$(dirname "$compiler")"
    binds+=(--ro-bind "$compiler_dir" "$compiler_dir" --ro-bind "$library" "$library")

    exec bwrap \
      --unshare-all \
      --die-with-parent \
      --new-session \
      --clearenv \
      "${binds[@]}" \
      --bind "$workdir" /work \
      --tmpfs /tmp \
      --proc /proc \
      --dev /dev \
      --chdir /work \
      --hostname playground \
      --setenv PATH /usr/bin:/bin \
      --setenv HOME /work \
      --setenv TMPDIR /tmp \
      --setenv LANG C.UTF-8 \
      --setenv PUDU_LIB "$library" \
      --setenv GHCRTS "$heap" \
      "$compiler" "${command_line[@]}"
    ;;
  confined|none)
    cd "$workdir"
    exec env -i \
      PATH=/usr/bin:/bin \
      HOME="$workdir" \
      TMPDIR="$workdir" \
      LANG=C.UTF-8 \
      PUDU_LIB="$library" \
      GHCRTS="$heap" \
      "$compiler" "${command_line[@]}"
    ;;
  *)
    refuse "isolation must be bwrap, confined, or none, not '$isolation'"
    ;;
esac
