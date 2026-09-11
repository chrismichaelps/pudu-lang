#!/usr/bin/env bash
# Build a Pudu runtime that runs on any Linux, whatever C library the host has.
#
# A bundle is a runtime with a program appended, so where a bundle can run is
# decided entirely by how its runtime was linked. Built against the glibc of a
# current Linux it records a version requirement — `GLIBC_2.34` from a 24.04
# host — and refuses to start anywhere older: AWS Lambda, which is what Vercel
# functions run on, and every Alpine image. The failure arrives from the loader
# before any Pudu code runs, so nothing in the program can report it.
#
# Linking against musl removes the version requirement rather than raising it.
# It also fixes name resolution: statically linked glibc resolves hostnames
# through NSS modules it loads at run time, which a static link does not carry,
# so `Net.connect(host, port)` fails for every name. musl resolves names in the
# library itself.
#
# What this produces is dynamically linked against musl and its named C
# libraries. That is deliberate. A fully static binary cannot `dlopen`, and `cbits/pudu_ffi.c` and
# `cbits/pudu_sqlite.c` load libraries that way, so a fully static runtime would
# silently be one with no `Std.Foreign` and no SQLite driver. A Lambda package
# carries the musl loader and every shared dependency beside the runtime.
#
# The build runs in a container because GHC needs a musl toolchain to target
# one, and cross-compiling GHC is considerably harder than borrowing a machine
# that already is the target. The toolchain is built here rather than pulled:
# no published musl image carries a GHC new enough, since the package needs
# `base >= 4.20` — GHC 9.10 — and the images that exist stop at 9.4. The image
# is kept, so building it is a cost paid once.
#
# The runtime is for x86_64, which is what Lambda and every serverless platform
# built on it runs. On a machine that is not x86_64 the container is emulated
# and a GHC build under emulation takes hours, so the script says so rather than
# appearing to hang.
#
# Usage:
#   scripts/build-musl-runtime.sh [-o output]
#
# Environment:
#   PUDU_MUSL_IMAGE   the toolchain image to build in
#   PUDU_MUSL_PLATFORM  the platform to build for, default linux/amd64
#   PUDU_MUSL_ENGINE  docker (default) or podman
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
output="$root/dist/pudu-musl-x86_64"
engine="${PUDU_MUSL_ENGINE:-docker}"

# The toolchain image, built from deploy/musl.Dockerfile when it is not there.
image="${PUDU_MUSL_IMAGE:-pudu-musl-toolchain:ghc9.10.1}"
platform="${PUDU_MUSL_PLATFORM:-linux/amd64}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      [[ $# -ge 2 ]] || { echo "build-musl-runtime: -o needs a path" >&2; exit 2; }
      output="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "build-musl-runtime: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done

output_dir="$(dirname "$output")"
lambda_output="${PUDU_MUSL_LAMBDA_OUTPUT:-$output_dir/pudu-musl-lambda-x86_64}"
loader_output="${PUDU_MUSL_LOADER_OUTPUT:-$output_dir/ld-musl-x86_64.so.1}"
library_output_dir="${PUDU_MUSL_LIBRARY_OUTPUT_DIR:-$(dirname "$loader_output")}"

if ! command -v "$engine" >/dev/null 2>&1; then
  echo "build-musl-runtime: $engine is not installed" >&2
  echo "  set PUDU_MUSL_ENGINE=podman to use podman instead" >&2
  exit 1
fi

if ! "$engine" info >/dev/null 2>&1; then
  echo "build-musl-runtime: $engine is installed but not running" >&2
  exit 1
fi

# Emulating another architecture is the difference between minutes and hours for
# a GHC build, and a reader watching it would have no way to tell which they are
# in. Said once, here.
host="$("$engine" info --format '{{.Architecture}}' 2>/dev/null || echo unknown)"
case "$host" in
  x86_64 | amd64) ;;
  *)
    echo "build-musl-runtime: this machine is $host and the runtime is for x86_64." >&2
    echo "  The container will be emulated, and a GHC build under emulation takes" >&2
    echo "  hours rather than minutes. The CI job musl-runtime.yml builds this on" >&2
    echo "  an x86_64 runner; downloading its artefact is the faster path." >&2
    echo "  Continuing anyway." >&2
    ;;
esac

if ! "$engine" image inspect "$image" >/dev/null 2>&1; then
  echo "building the toolchain image $image (once; this takes a while)"
  "$engine" build \
    --platform "$platform" \
    -f "$root/deploy/musl.Dockerfile" \
    -t "$image" \
    "$root/deploy"
fi

mkdir -p "$output_dir" "$(dirname "$lambda_output")" "$(dirname "$loader_output")" "$library_output_dir"

# The build runs as the invoking user so the artefact is not left owned by root,
# and HOME is inside the mount so cabal's package database survives between runs
# rather than being downloaded again each time.
"$engine" run --rm \
  --platform "$platform" \
  --volume "$root:/work" \
  --workdir /work/packages/pudu/v0.1 \
  --env HOME=/work/dist/musl-home \
  --user "$(id -u):$(id -g)" \
  "$image" \
  sh -eu -c '
    mkdir -p /work/dist/musl-home
    cabal update

    # The Haskell libraries are linked in by default. C dependencies stay
    # dynamic so foreign-library loading remains available; the Lambda package
    # carries the exact musl libraries that dependency inspection names.
    cabal build exe:pudu \
      --disable-tests \
      --enable-optimization=2

    cp "$(cabal list-bin exe:pudu --disable-tests --enable-optimization=2)" /work/dist/pudu-musl-built
    cp /work/dist/pudu-musl-built /work/dist/pudu-musl-lambda-built
    cp /lib/ld-musl-x86_64.so.1 /work/dist/ld-musl-x86_64-built.so.1
    patchelf --set-interpreter /var/task/ld-musl-x86_64.so.1 \
      /work/dist/pudu-musl-lambda-built
    for dependency in libffi.so.8 libz.so.1 libncursesw.so.6 libgmp.so.10; do
      resolved="$(ldd /work/dist/pudu-musl-built | \
        awk -v wanted="$dependency" '\''$1 == wanted { print $3 }'\'')"
      if [ -z "$resolved" ]; then
        echo "could not resolve $dependency from the built runtime" >&2
        exit 1
      fi
      cp -L "$resolved" "/work/dist/$dependency-built"
      patchelf --replace-needed "$dependency" "/var/task/$dependency" \
        /work/dist/pudu-musl-lambda-built
    done
    resolved="$(ldd /work/dist/libncursesw.so.6-built | \
      awk '\''$1 == "libtinfo.so.6" { print $3 }'\'')"
    if [ -z "$resolved" ]; then
      echo "could not resolve libtinfo.so.6 from libncursesw.so.6" >&2
      exit 1
    fi
    cp -L "$resolved" /work/dist/libtinfo.so.6-built
    patchelf --replace-needed libtinfo.so.6 /var/task/libtinfo.so.6 \
      /work/dist/libncursesw.so.6-built
  '

mv "$root/dist/pudu-musl-built" "$output"
mv "$root/dist/pudu-musl-lambda-built" "$lambda_output"
mv "$root/dist/ld-musl-x86_64-built.so.1" "$loader_output"
for dependency in libffi.so.8 libz.so.1 libncursesw.so.6 libtinfo.so.6 libgmp.so.10; do
  mv "$root/dist/$dependency-built" "$library_output_dir/$dependency"
done
chmod +x "$output"
chmod +x "$lambda_output" "$loader_output"

# What was actually produced, rather than what was asked for. A link that
# quietly fell back to the host C library produces a file that builds, passes a
# smoke test on the build machine, and fails on the platform — which is the
# failure this whole script exists to prevent, so it is checked here.
echo
echo "built $output"
echo "built $lambda_output"
echo "copied $loader_output"
echo "copied musl libraries to $library_output_dir"
"$engine" run --rm --platform "$platform" --volume "$output:/runtime:ro" "$image" sh -eu -c '
  echo "--- what it is ---"
  file /runtime || true
  echo "--- what it needs at run time ---"
  ldd /runtime 2>&1 || true
'

if "$engine" run --rm --platform "$platform" --volume "$output:/runtime:ro" "$image" sh -c 'ldd /runtime 2>&1' | grep -qi "libc\.so\.6\|GLIBC"; then
  echo >&2
  echo "build-musl-runtime: the runtime still needs glibc, which is the thing this avoids." >&2
  echo "  It will not start on Lambda or on Alpine. Check that the image is a musl one." >&2
  exit 1
fi

echo
echo "This runtime is for Linux, so it cannot be run here to check it."
echo "Attach a program to it with:"
echo "  pudu build <file> -o <artefact> --runtime $output"
echo "The compiler doing that must be the same version of Pudu as this runtime."
