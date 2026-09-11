# A toolchain that builds Pudu against musl.
#
# Built here rather than pulled, because no published musl image carries a GHC
# new enough: the package needs `base >= 4.20`, which is GHC 9.10, and the
# images that exist stop at 9.4. Building the toolchain once and keeping the
# image is what makes the runtime build afterwards take minutes.
#
# Alpine is the base because it *is* musl — nothing here has to arrange for a
# different C library than the one the system uses, which is the arrangement
# that goes wrong.
FROM alpine:3.20

# What GHC needs to run and what the package needs to link against. `gmp` is
# whole-number arithmetic, `libffi` the foreign interface, `zlib` compression,
# `ncurses` the interactive session. The `-static` packages are the archives the
# runtime is linked from, so the finished binary needs none of them present.
RUN apk add --no-cache \
      bash binutils build-base coreutils curl git gmp-dev gnupg \
      libffi-dev ncurses-dev patchelf perl tar xz zlib-dev \
      ncurses-static zlib-static

ARG GHC_VERSION=9.10.1
ARG CABAL_VERSION=3.12.1.0

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_MINIMAL=1 \
    GHCUP_INSTALL_BASE_PREFIX=/opt \
    PATH=/opt/.ghcup/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh \
  && ghcup install ghc "${GHC_VERSION}" --set \
  && ghcup install cabal "${CABAL_VERSION}" --set \
  && ghcup gc --profiling-libs --share-dir \
  && cabal update

WORKDIR /work
