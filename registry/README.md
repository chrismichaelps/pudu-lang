# Pudu package registry

The registry that `pudu install @handle/name`, `pudu login`, `pudu push`, and `pudu release` talk
to. It keeps everything in one data directory and answers the API described in
`wiki/architecture/PACKAGES.md`.

```sh
pudu run registry/src/Main.pudu serve --data ./registry-data --port 8790
pudu run registry/src/Main.pudu account --data ./registry-data --handle alice --password '…'
pudu run registry/src/Main.pudu token --data ./registry-data --handle alice --scope read
pudu test registry/src/Test/Registry.pudu
```

`account` and `token` print a token for `pudu login --token`. People can also create an account at
`/signup` and pair a machine at `/login/device`.

| Option | Default | Meaning |
| --- | --- | --- |
| `--data` | `registry-data` | directory holding accounts, projects, and archives |
| `--host` | `127.0.0.1` | address to listen on |
| `--port` | `8790` | port to listen on |
| `--url` | `http://host:port` | address readers reach the registry at, used in pairing links |
