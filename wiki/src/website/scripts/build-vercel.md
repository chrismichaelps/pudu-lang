---
type: script
path: "@root/website/scripts/build-vercel.sh"
fidelity: Active
tags: [website, vercel, build]
aliases: [Vercel output builder]
---
# Vercel Output Builder

Produces a Build Output API v3 directory (`.vercel/output`) from the public catalogue, the lightweight
Node.js search function, static CSS, Nunito fonts, logos, and 3,375 pre-rendered canonical HTML pages
captured from a local Pudu server. Configures `"architecture": "x86_64"` and file permissions (`chmod 644`).
Deploys efficiently using `vercel deploy --prebuilt --archive=tgz` to package output into a single archive,
avoiding daily free-tier file count thresholds.

Resolved Grill Log: the script assembles deterministic deployment output without requiring an external
Linux ELF binary or risking container GLIBC mismatches. Dynamic search reaches the lightweight serverless
handler; all other routes resolve directly from Vercel's global static Edge CDN.
