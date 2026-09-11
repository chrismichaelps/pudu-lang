---
type: script
path: "@root/website/scripts/build-vercel.sh"
fidelity: Active
tags: [website, vercel, build]
aliases: [Vercel output builder]
---
# Vercel Output Builder

Produces a Build Output API v3 directory (`.vercel/output`) from the public catalogue, a Pudu Lambda
function, static CSS, Nunito fonts, logos, and canonical HTML pages rendered directly by Pudu. The
function contains the Lambda-targeted musl runtime and its loader; no JavaScript adapter is included.
The matching musl `libffi`, `zlib`, `ncursesw`, and `gmp` libraries are copied beside the
function and named directly by its ELF dependencies.
The API catalogue is packaged at `website/data/api.json`, matching the Pudu configuration default
used when Vercel starts the function in `/var/task`.

Resolved Grill Log: dynamic search reaches the same Pudu router and ranking service as local requests
and tests, while canonical pages resolve directly from Vercel's static edge output. The builder refuses
to package a function unless both the Lambda runtime and its matching musl loader are present.
It also refuses any missing shared dependency named by the runtime package contract.
The emitted function uses Vercel's current custom-runtime target, `provided.al2023`.
The function is named `dynamic.func`, avoiding the root-path shadowing caused by `index.func`.
