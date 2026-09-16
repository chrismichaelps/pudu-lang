---
type: script
path: "@root/website/scripts/build-linux-renderer.sh"
fidelity: Active
tags: [website, pudu, linux, build]
aliases: [Linux Pudu renderer builder]
---
# Linux Pudu Renderer Builder

Attaches the website server and Lambda function to the corresponding x86-64 musl runtimes, then
places the executables under `website/bin/` for Linux-host and function inspection.

Resolved Grill Log: the ordinary Linux server keeps the normal musl interpreter, while the function
uses the Lambda-targeted runtime and packaged `/var/task` loader path.
