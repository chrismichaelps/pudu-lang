# Pudu package registry

The registry that `pudu install @owner/repo`, `pudu login`, `pudu push`, and `pudu release` talk to.
Accounts and source are GitHub's: `@owner/repo` is `github.com/owner/repo`, a request is authenticated
by a GitHub token, and a release is the commit a tag names, fetched from GitHub and kept here as an
immutable archive. It keeps everything in one data directory and answers the API described in
`wiki/architecture/PACKAGES.md`.

```sh
pudu run registry/src/Main.pudu serve --data ./registry-data --port 8790 --github-client-id <id>
pudu test registry/src/Test/Registry.pudu
```

`pudu login` runs GitHub's device flow with the OAuth application the registry names, so the
application must have device flow enabled; it needs no client secret.

| Option | Default | Meaning |
| --- | --- | --- |
| `--data` | `registry-data` | directory holding projects, releases, and profiles |
| `--host` | `127.0.0.1` | address to listen on |
| `--port` | `8790` | port to listen on |
| `--url` | `http://host:port` | address readers reach the registry at |
| `--github-client-id` | `REGISTRY_GITHUB_CLIENT_ID` | OAuth client id `pudu login` uses |
| `--github-url` | `https://github.com` | GitHub's site, for the device flow |
| `--github-api` | `https://api.github.com` | GitHub's API |
