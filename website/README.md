# Pudu website

The website is a server-rendered Pudu application. Its dependency rules are documented in
`wiki/architecture/WEBSITE.md`.

Live production URL: **https://website-ivory-one-hyy8j9ljag.vercel.app/**

## Local development

```bash
website/scripts/generate-catalog.sh pudu
pudu check website/src/Main.pudu website/src/Render.pudu
pudu fmt --check website/src/Main.pudu website/src/Render.pudu
pudu test website/src/Test/Website.pudu
pudu run website/src/Main.pudu
```

Open `http://127.0.0.1:8080`. Set `PUDU_SITE_URL` to the public HTTPS origin before a production
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
against a current glibc cannot start on the Lambda a Vercel function runs on:

```bash
scripts/build-musl-runtime.sh -o dist/pudu-musl-x86_64

PUDU_SITE_URL=https://website-ivory-one-hyy8j9ljag.vercel.app \
website/scripts/build-vercel.sh

vercel deploy --prebuilt --archive=tgz --prod
```

No server is started to produce the static pages. `Prerender.pudu` calls `Web.render` for every path
`Seo.paths` lists, so the pages and the sitemap cannot disagree about which pages exist.
