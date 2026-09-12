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
Main / Render / Prerender        Function
           |                        |
       Web.Routes              Web.Dynamic
          /  \                   /      \
       View  Service.Catalog  View.Dynamic  Service.Search
         \       /                \          /
          Seo / Constants          Domain.Entry

SearchIndex -> Service.Catalog -> generated compact search database
```

Config and Error are leaf policies used from the composition edge. SEO owns canonical metadata,
structured data, robots policy, and sitemap rendering; views choose page facts but do not spell tags.

Dependencies point downward. Domain code knows no HTTP or HTML. Services know catalogue and query
values, not requests. Views receive values and return typed `Std.Html` trees. The static router owns
the complete crawlable documentation graph. The dynamic router owns only search and the no-index
fallback, so the Lambda closure does not retain static-page machinery.

## Search contract

Search data is generated from the validated `pudu doc --json` catalogue before deployment. The
dynamic function receives only fields required by query matching and result rendering. It never
reparses source files and never owns a second documentation truth.

A query is parsed into independent name terms, an optional Pudu type shape, an optional module
filter, an optional declaration-kind filter, and exact-name intent. `module:Std.List`, `kind:fn`, and
`is:exact` are the closed filter vocabulary. A type may follow `::`; a filter-free query containing
`->` is also a type query. Unknown `name:value` tokens remain ordinary search terms.

Cheap scope and token tests run before type-shape comparison. Ranking is deterministic: exact module
leaf intent, exact qualified and unqualified names, prefixes, complete token matches, structural
type matches, and documentation matches descend in that order, with qualified name as the stable
tie-break. A plain `List` query surfaces every `Std.List` declaration before unrelated names that
contain `list`; the result bound is large enough to keep the complete current module visible.

Pudu type matching preserves concrete constructors, references, mutability, result channels,
constraints, and argument order. It normalizes insignificant whitespace, case for search, and
single-letter generic placeholder names. It does not apply Haskell-specific alias, type-class, or
argument-reordering rules. Ranking fixtures assert top-hit and top-N positions, not only presence.

Every public standard-library declaration must carry a non-empty source-owned summary. Richer
comments may add usage, parameter, return, failure, and example sections. Symbol pages render that
material and related declarations without inventing semantics in the view layer. Documentation
examples join the executable example gate before publication.

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
The function package preserves the generated compact search database under `/var/task`; full
`website/data/api.json` remains a build input for static documentation only.
CI proves the attached Pudu program first on Alpine and then in Amazon Linux 2023 with the same
`/var/task` layout used by Lambda.

Vercel wraps its HTTP request document in the invocation event's textual `body`. The Pudu function
unwraps that one transport envelope, then applies the same path and query rules as local routing.
Function metadata supplies the canonical production origin so dynamic pages agree with static SEO
metadata after promotion.

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
- **Q:** Treat search as one case-insensitive substring? **A:** No. _Rationale:_ names, module scope,
  declaration kind, prose, and Pudu type structure carry different intent and need separate parsing,
  prefilters, and ranking evidence. _Rejected:_ one score chosen by the first matching field.
- **Q:** Copy Hoogle's rewrite system? **A:** No. _Rationale:_ its build-time index, separated query
  parts, cheap candidate filters, and ranking fixtures are useful evidence, but Pudu has different
  ownership and failure types. _Rejected:_ importing Haskell aliases, contexts, or argument reorder.
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
