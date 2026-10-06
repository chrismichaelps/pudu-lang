# Pudu website

The website is a server-rendered Pudu application. Its dependency rules are documented in
`wiki/architecture/WEBSITE.md`.

Live production URL: **https://www.pudu-lang.org/**

## Local development

```bash
website/scripts/dev.sh
```

Open `http://localhost:8080`. Saving any Pudu source, documentation page, stylesheet, script, data
file, or playground example starts the site again, and every open page follows: it reloads, or takes
new styles in place when only a stylesheet changed, keeping its scroll position. There is nothing to
configure — the script runs the site under `pudu run --watch`, which tells the site it is watched
(`website/src/Web/LiveReload.pudu`); a site not run that way serves exactly what it deploys.
`PUDU` names another compiler and `PUDU_SITE_PORT` another port.

## Packages

The site is a Pudu project built on three packages: `pudu-lang-mediator` routes every page and
playground command, `pudu-lang-log` writes its structured logs, and `pudu-lang-validator` checks what
readers send and what the environment configures. `website/pudu.toml` names them and
`website/pudu.lock` pins them; they are installed into `website/deps/`, which is never committed:

```bash
(cd website && pudu install --locked)
```

`website/scripts/dev.sh` and `website/scripts/build-vercel.sh` run that themselves. Without it, every
compile under `website/` stops with `E7202` naming the packages to install.

## Application layer and logs

A router turns a request into a typed message (`website/src/App/Messages.pudu`), sends it to the
mediator the application built once at startup, and turns the outcome into a response. Every message
passes the same layers: a fault alarm, the mediator's logging recorder, validation, and, for the
playground, admission and a run audit. A query longer than the site reads is answered with a no-index
`400` naming the field.

Logs go to standard error: one event per request (method, path, status, milliseconds — never the query
string), failures from the mediator, and every playground run without the reader's address.

| Setting | Values | Default |
| --- | --- | --- |
| `PUDU_SITE_LOG_LEVEL` | `verbose`, `debug`, `information`, `warning`, `error`, `fatal` | `information`; the renderer and prerender use `warning` unless set |
| `PUDU_SITE_LOG_FORMAT` | `text`, `console` (coloured), `json` | `text`; `dev.sh` uses `console`, the Vercel function `json` |

A level of `debug` or `verbose` also shows every message's start and end. Every wrong setting, the
site's and the playground's, is named in one refusal at startup.

## Checks

Regenerating the data the site reads, and the checks continuous integration runs:

```bash
website/scripts/generate-catalog.sh pudu
node website/scripts/generate-releases.mjs
(cd website && pudu install --locked)
pudu check $(find website/src -name '*.pudu')
pudu fmt --check website/src website/playground/examples
pudu test website/src/Test/Website.pudu website/src/Test/Application.pudu website/src/Test/Playground.pudu
```

`generate-releases.mjs` writes `website/data/releases.json` from the published releases, which is
what `/download` offers. The archives are read at build time rather than per request, so a reader on
the CDN waits for no API and a rate limit at the forge cannot take the download page down; the cost
is that a new release reaches the page on the next deployment. Run it again after publishing one.

Packages are different: the build's snapshot is the baseline, and the function lays GitHub's
`topic:pudu-package` search over it, so a newly published package is listed and has its page within
minutes, without a deployment. Answers are cached at the edge and per function instance; when GitHub
refuses or times out the snapshot is served. Give the function a `GITHUB_TOKEN` environment variable
(no scopes needed) to raise its API rate limit.

Set `PUDU_SITE_URL` to the public HTTPS origin before a production
build so canonical URLs, Open Graph URLs, `robots.txt`, and `sitemap.xml` agree.

`Main.pudu` owns the local HTTP listener. `Function.pudu` serves a platform that invokes the program
rather than connecting to it, through `Std.Http.Server.Lambda`. `Render.pudu` handles one URL and
exits. All three serve `Web.Routes`, so every page has one description and ranked search has one
implementation — `Service.Search`, the one `Test/Website.pudu` checks.

Vercel routes pre-rendered canonical HTML directly through the Edge CDN. Dynamic routes reach the
Pudu function. There is no JavaScript in the deployment: the ranked search that used to be
reimplemented in `website/platform/vercel/index.js` is gone, along with the second copy of the
scoring table it carried.

## Vercel production build & deploy

Assemble Build Output API v3 with the canonical HTTPS origin and deploy using compressed archive.
The function is a Pudu artefact attached to a runtime linked against musl, because a runtime linked
against a current glibc cannot start on the Lambda a Vercel function runs on. The runtime builder
also writes `dist/pudu-musl-lambda-x86_64` and packages its matching loader as
`dist/ld-musl-x86_64.so.1`:

```bash
scripts/build-musl-runtime.sh -o dist/pudu-musl-x86_64

PUDU_SITE_URL=https://www.pudu-lang.org \
website/scripts/build-vercel.sh

vercel deploy --prebuilt --archive=tgz --prod
```

No server is started to produce the static pages. `Prerender.pudu` calls `Web.render` for every path
`Seo.paths` lists, so the pages and the sitemap cannot disagree about which pages exist.
