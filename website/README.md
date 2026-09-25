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

Regenerating the data the site reads, and the checks continuous integration runs:

```bash
website/scripts/generate-catalog.sh pudu
node website/scripts/generate-releases.mjs
pudu check website/src/Main.pudu website/src/Render.pudu
pudu fmt --check website/src/Main.pudu website/src/Render.pudu
pudu test website/src/Test/Website.pudu
```

`generate-releases.mjs` writes `website/data/releases.json` from the published releases, which is
what `/download` offers. The archives are read at build time rather than per request, so a reader on
the CDN waits for no API and a rate limit at the forge cannot take the download page down; the cost
is that a new release reaches the page on the next deployment. Run it again after publishing one.

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
