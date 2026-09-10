FROM haskell:9.10.3-slim-bookworm

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential libffi-dev libgmp-dev pkg-config zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY . .

RUN cabal update \
  && cabal build exe:pudu \
  && compiler="$(cabal list-bin exe:pudu)" \
  && "$compiler" build website/src/Main.pudu -o /tmp/pudu-site-server \
  && chmod +x /tmp/pudu-site-server

CMD ["cp", "/tmp/pudu-site-server", "/output/pudu-site-server-linux-x64"]
