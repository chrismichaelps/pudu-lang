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

`Main.pudu` owns the local HTTP listener. `Render.pudu` handles one URL and exits for a serverless
runtime. Vercel routes pre-rendered canonical HTML directly through Edge CDN, and handles dynamic
ranked search via an in-memory Node.js function loaded from `data/api.json`.

## Vercel production build & deploy

Assemble Build Output API v3 with the canonical HTTPS origin and deploy using compressed archive:

```bash
PUDU_SITE_URL=https://website-ivory-one-hyy8j9ljag.vercel.app \
PUDU_STATIC_SERVER=website/bin/pudu-site-server-macos \
website/scripts/build-vercel.sh

vercel deploy --prebuilt --archive=tgz --prod
```
