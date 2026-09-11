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
# What this produces is dynamically linked against musl and nothing else, so it
# needs one file present at run time — musl's loader. That is deliberate. A
# fully static binary cannot `dlopen`, and `cbits/pudu_ffi.c` and
# `cbits/pudu_sqlite.c` load libraries that way, so a fully static runtime would
# silently be one with no `Std.Foreign` and no SQLite driver. Every other C
# library is linked in, so the loader is the only dependency.
#
# The build runs in a container because GHC needs a musl toolchain to target
# one, and cross-compiling GHC is considerably harder than borrowing a machine
# that already is the target. The image is pinned by digest: an image tag is
# rewritten by whoever publishes it, and a runtime that quietly changed the
# library it links against is the thing this script exists to prevent.
#
# Usage:
#   scripts/build-musl-runtime.sh [-o output]
#
# Environment:
#   PUDU_MUSL_IMAGE   the image to build in, pinned by digest
#   PUDU_MUSL_ENGINE  docker (default) or podman
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
output="$root/dist/pudu-musl-x86_64"
engine="${PUDU_MUSL_ENGINE:-docker}"

# GHC built against musl, with the C libraries the package needs. Replace this
# with a digest for the version you intend to keep; a bare tag is accepted so
# the script can be run before one is chosen, and warns when it is.
image="${PUDU_MUSL_IMAGE:-docker.io/utdemir/ghc-musl:v25-ghc9101}"

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

if ! command -v "$engine" >/dev/null 2>&1; then
  echo "build-musl-runtime: $engine is not installed" >&2
  echo "  set PUDU_MUSL_ENGINE=podman to use podman instead" >&2
  exit 1
fi

if ! "$engine" info >/dev/null 2>&1; then
  echo "build-musl-runtime: $engine is installed but not running" >&2
  exit 1
fi

case "$image" in
  *@sha256:*) ;;
  *)
    echo "build-musl-runtime: the image is named by tag rather than by digest." >&2
    echo "  A tag is rewritten by whoever publishes it, so two runs of this can" >&2
    echo "  link against different libraries. Pin PUDU_MUSL_IMAGE to a digest" >&2
    echo "  before anything is released from it." >&2
    ;;
esac

mkdir -p "$(dirname "$output")"

# The build runs as the invoking user so the artefact is not left owned by root,
# and HOME is inside the mount so cabal's package database survives between runs
# rather than being downloaded again each time.
"$engine" run --rm \
  --volume "$root:/work" \
  --workdir /work/packages/pudu/v0.1 \
  --env HOME=/work/dist/musl-home \
  --user "$(id -u):$(id -g)" \
  "$image" \
  sh -eu -c '
    mkdir -p /work/dist/musl-home
    cabal update

    # The Haskell libraries are linked in by default. These are the C ones the
    # package names, linked in as well so the finished runtime needs nothing but
    # the loader: libffi for the foreign interface, zlib for Std.Compress,
    # ncurses for the interactive session, gmp for whole-number arithmetic.
    cabal build exe:pudu \
      --disable-tests \
      --enable-optimization=2 \
      --ghc-options="-optl-Wl,-Bstatic -optl-lffi -optl-lz -optl-lncursesw -optl-lgmp -optl-Wl,-Bdynamic"

    cp "$(cabal list-bin exe:pudu --disable-tests --enable-optimization=2)" /work/dist/pudu-musl-built
  '

mv "$root/dist/pudu-musl-built" "$output"
chmod +x "$output"

# What was actually produced, rather than what was asked for. A link that
# quietly fell back to the host C library produces a file that builds, passes a
# smoke test on the build machine, and fails on the platform — which is the
# failure this whole script exists to prevent, so it is checked here.
echo
echo "built $output"
"$engine" run --rm --volume "$output:/runtime:ro" "$image" sh -eu -c '
  echo "--- what it is ---"
  file /runtime || true
  echo "--- what it needs at run time ---"
  ldd /runtime 2>&1 || true
'

if "$engine" run --rm --volume "$output:/runtime:ro" "$image" sh -c 'ldd /runtime 2>&1' | grep -qi "libc\.so\.6\|GLIBC"; then
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
