---
type: module
path: "@root/website/src/Service/Playground/Sandbox.pudu"
fidelity: Active
tags: [website, playground, service]
aliases: [website Service Playground Sandbox]
---
# Website Playground Sandbox

Places each program in its own directory, runs `sandbox.sh` with arguments only, reads both streams with an output bound, stops on overflow or deadline, and removes the directory. The library's resolved directory is removed from every place a diagnostic names.

Resolved Grill Log: the sandbox exit status 125 means isolation was impossible and is reported as unavailable, never as the reader's failure.
