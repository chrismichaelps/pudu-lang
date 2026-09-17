# The website playground's runner: the service that runs what readers write.
#
# Build the runtime and the runner before this, from the repository root:
#
#   scripts/build-musl-runtime.sh -o dist/pudu-musl-x86_64
#   pudu build website/src/PlaygroundRunner.pudu -o dist/playground-runner \
#     --runtime dist/pudu-musl-x86_64
#   docker build --platform linux/amd64 -f deploy/playground-runner.Dockerfile \
#     -t pudu-playground-runner .
#
# The image carries two Pudu executables. `playground-runner` is the service.
# `pudu` is the compiler it runs each program with, beside the standard library
# those programs import. Both come from the same runtime, so a program in the
# playground is compiled by the release it was written for.
#
# Isolation is bubblewrap, which needs the host to let an unprivileged process
# create user namespaces. Run the image under gVisor (`--runtime=runsc`), on a
# platform that runs each container in its own virtual machine, or on a host
# whose seccomp and AppArmor policies admit `unshare`. Where they do not, the
# sandbox refuses to run anything and the runner answers that it cannot
# isolate programs. It never falls back to running them unisolated. The
# settings the runner reads are listed in the ENV block below.
FROM alpine:3.20

# `bash` runs the sandbox script and `bubblewrap` is the sandbox. The four
# libraries are the ones the musl runtime links, and `ca-certificates` is the
# trust store `Std.Tls` reads. A program in the playground cannot reach the
# network, but the runner's own client code still loads the store.
RUN apk add --no-cache \
      bash bubblewrap ca-certificates gmp libffi ncurses-libs zlib \
  && adduser -D -H -u 10001 runner

COPY dist/pudu-musl-x86_64 /usr/local/bin/pudu
COPY packages/pudu/v0.1/lib /usr/local/lib/pudu
COPY dist/playground-runner /usr/local/bin/playground-runner
COPY website/playground/sandbox.sh /usr/local/libexec/pudu-playground-sandbox
RUN chmod 0555 /usr/local/bin/pudu /usr/local/bin/playground-runner \
      /usr/local/libexec/pudu-playground-sandbox \
  && chmod -R a+rX,go-w /usr/local/lib/pudu

# Every setting the runner reads, written out so the image documents itself.
# The secret the website presents, PUDU_PLAYGROUND_TOKEN, is not here: it is
# given to the container when it starts, and the runner refuses to listen
# beyond the loopback address without it.
ENV PUDU_RUNNER_HOST=0.0.0.0 \
    PUDU_RUNNER_PORT=8090 \
    PUDU_PLAYGROUND_SANDBOX=/usr/local/libexec/pudu-playground-sandbox \
    PUDU_PLAYGROUND_COMPILER=/usr/local/bin/pudu \
    PUDU_PLAYGROUND_LIBRARY=/usr/local/lib/pudu \
    PUDU_PLAYGROUND_ISOLATION=bwrap \
    PUDU_PLAYGROUND_WORKSPACE=/tmp \
    PUDU_PLAYGROUND_MEMORY_MB=256 \
    PUDU_PLAYGROUND_RUN_MS=10000 \
    PUDU_PLAYGROUND_OUTPUT_BYTES=65536 \
    PUDU_PLAYGROUND_SOURCE_BYTES=65536 \
    PUDU_PLAYGROUND_CONCURRENCY=4 \
    PUDU_PLAYGROUND_RUNS_PER_MINUTE=30 \
    PUDU_PLAYGROUND_CACHE_ENTRIES=256 \
    TMPDIR=/tmp

USER runner
EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -q -O /dev/null http://127.0.0.1:8090/health || exit 1

ENTRYPOINT ["/usr/local/bin/playground-runner"]
