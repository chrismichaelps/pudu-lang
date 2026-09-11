# A Pudu artefact in an image, for the platforms that run a daemon.
#
# Build the artefact before this, with a runtime linked against musl:
#
#   scripts/build-musl-runtime.sh -o dist/pudu-musl-x86_64
#   pudu build src/Main.pudu -o dist/server --runtime dist/pudu-musl-x86_64
#   docker build -f deploy/Dockerfile --build-arg ARTEFACT=dist/server -t my-service .
#
# The base is Alpine rather than `scratch`, which is the shorter Dockerfile and
# the wrong one. Three things a Pudu artefact needs are not in an empty image:
#
#   * musl's loader. The runtime is dynamically linked against musl so that
#     `dlopen` still works, which `Std.Foreign` and the SQLite driver need. A
#     fully static runtime would need no loader and would silently have neither.
#
#   * a writable temporary directory. A bundle carries its modules as source and
#     writes them out to a temporary directory each time it starts, so a root
#     filesystem with nowhere to write is a program that cannot start at all.
#     `scratch` has no `/tmp`, and an image cannot create one without a shell.
#
#   * certificate authorities. `Std.Tls` verifies against the host trust store,
#     so in an image without one every HTTPS connection fails to verify — which
#     looks like a broken server rather than a missing file.
#
# Alpine supplies all three and costs about eight megabytes over `scratch`. It
# also leaves a shell in the image, which is the difference between diagnosing a
# failure in production and redeploying to guess at one.
FROM alpine:3.20

# The loader and the trust store come from the base image. This is the package
# that carries the certificates; without it `Std.Tls` cannot verify anything.
RUN apk add --no-cache ca-certificates \
  && adduser -D -H -u 10001 pudu

ARG ARTEFACT=dist/server
COPY ${ARTEFACT} /usr/local/bin/server

# Run as nobody in particular. A Pudu artefact needs no privilege: it binds
# whichever port it was configured with, and a port below 1024 is the platform's
# to map rather than the program's to be trusted with.
USER pudu

# Written out rather than left to the default, because a bundle writes its
# modules here on every start and a platform that mounts this read-only stops
# the program before it runs. Cloud Run and Lambda both provide a writable
# `/tmp`; a hardened Kubernetes pod needs an `emptyDir` mounted at it.
ENV TMPDIR=/tmp

# What the program listens on is the program's to read from its configuration.
# This records the convention the platforms use so a reader knows which one to
# set; it binds nothing by itself.
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/server"]
