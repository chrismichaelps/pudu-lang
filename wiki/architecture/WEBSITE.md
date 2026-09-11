---
type: architecture
fidelity: Active
tags: [architecture, website, ssr, vercel]
aliases: [Pudu Website Architecture]
---
# Pudu Website Architecture

## Purpose

Serve the language guide and complete generated API catalogue from a Pudu application, with the
same routes and rendering used by the local server, static capture, and Vercel function.

## Dependency direction

```text
Main / Function / Render / Prerender
        |
     Web.Routes
      /      \
   View     Service
     |       /   \
    Seo    Search Catalog
     |              |
 Constants     Domain.Entry

Config and Error are leaf policies used from the composition edge. SEO owns canonical metadata,
structured data, robots policy, and sitemap rendering; views choose page facts but do not spell tags.
```

Dependencies point downward. Domain code knows no HTTP or HTML. Services know catalogue values,
not requests. Views receive values and return typed `Std.Html` trees. Routes are the only layer
that translates an HTTP request into a service call and a rendered response.

## Rendering and deployment

The local entry point starts `Std.Http.Server`. `Function.pudu` serves the Lambda Runtime API through
`Std.Http.Server.Lambda`, and `Prerender.pudu` calls the same router directly for every crawlable path.
The Vercel deployment therefore contains no JavaScript request adapter and no second search or page
implementation.

The deployment runtime is built against musl. The normal runtime keeps musl's standard interpreter
for Linux hosts. A Lambda copy points to `/var/task/ld-musl-x86_64.so.1`, and the matching loader is
packaged beside the Pudu function. The musl-built `libffi`,
`zlib`, `ncursesw`, and `gmp` shared libraries named by dependency inspection are packaged
beside it. Lambda ELF dependencies name their `/var/task` files directly so Vercel's host
`LD_LIBRARY_PATH` cannot substitute incompatible glibc libraries.
The function package preserves `website/data/api.json`, the same default catalogue path used by
local Pudu processes, relative to Lambda's `/var/task` working directory.
CI proves the attached Pudu program first on Alpine and then in Amazon Linux 2023 with the same
`/var/task` layout used by Lambda.

Static HTML, CSS, fonts, and the two supplied logos are served from Vercel's CDN and from Pudu
routes locally. The generated API catalogue comes from `pudu doc --json`, so public documentation
cannot drift silently from the compiler's current declarations. Canonical documentation remains
server-rendered HTML even when build-time capture makes delivery static.

Search result URLs are crawlable so a `noindex,follow` directive can be read, but they are excluded
from the sitemap. Canonical module and symbol URLs are linked from complete HTML indexes. One root
XML sitemap covers the current catalogue while it remains below the protocol's 50,000 URL limit.

## Grill Log

- **Q:** Reimplement requests or search in JavaScript for Vercel? **A:** No. _Rationale:_ the product
  is evidence that Pudu can serve its own production documentation surface. _Rejected:_ a Node or
  React adapter with duplicate routing, ranking, or rendering.
- **Q:** Load the catalogue for every invocation? **A:** No. _Rationale:_ the Pudu function loads it
  before entering the Lambda invocation loop, so warm invocations reuse the same values. _Rejected:_
  repeated catalogue decoding inside the request callback.
- **Q:** Hand-maintain thousands of API records? **A:** No. _Rationale:_ the compiler already owns
  names, kinds, signatures, and documentation. _Rejected:_ a second catalogue source.
- **Q:** Build a native artifact on macOS and deploy it to Linux? **A:** No. _Rationale:_ CI builds
  the x86-64 runtime against musl and proves its Lambda layout on Amazon Linux 2023. _Rejected:_
  committing a local binary as a portable release.
- **Q:** Force every Linux Pudu bundle to use Lambda's `/var/task` loader path? **A:** No. _Rationale:_
  the ordinary runtime remains suitable for Linux hosts; only its Lambda copy receives the platform
  interpreter path. _Rejected:_ making a serverless packaging detail part of every Linux bundle.
- **Q:** Assume requested static linker flags made every C library static? **A:** No. _Rationale:_
  dependency inspection showed four dynamic musl libraries, so the Lambda artifact carries the exact
  files it names and searches beside itself. _Rejected:_ calling an artifact self-contained without
  executing it on a host where those libraries are absent.
- **Q:** Rely on `$ORIGIN` alone for Lambda library selection? **A:** No. _Rationale:_ Vercel injects
  host library paths ahead of the package and musl can select same-named glibc objects. Direct
  `/var/task` dependency names make the selected files deterministic. _Rejected:_ accepting a clean
  Amazon Linux container as proof of Vercel's different environment.
- **Q:** Name the dynamic function `index.func`? **A:** No. _Rationale:_ that function path shadows
  the static root page before the explicit root rewrite. _Rejected:_ invoking Pudu for a page already
  present in static output.

Resolved Grill Log: one Pudu rendering and search core, Pudu-native runtime edges, generated API
data, typed HTML, explicit errors, and no reverse dependency from domain or services into transport.
