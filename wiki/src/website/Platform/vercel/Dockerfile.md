---
type: build
path: "@root/website/platform/vercel/Dockerfile"
fidelity: Active
tags: [website, vercel, linux, container]
aliases: [Vercel Linux build image]
---
# Vercel Linux Build Image

Builds the repository compiler and then uses that compiler to bundle `Main.pudu` for Linux x86-64.
The image writes only the deployment server to the mounted output directory.

Resolved Grill Log: the image pins the compiler family and Debian generation while Cabal's pinned
index-state and lockable project constraints own Haskell dependency selection.
