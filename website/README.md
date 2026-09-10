# Pudu website

The website is a server-rendered Pudu application. Its dependency rules are documented in
`wiki/architecture/WEBSITE.md`.

```bash
website/scripts/generate-catalog.sh pudu
pudu check website/src/Main.pudu website/src/Render.pudu
pudu fmt --check website/src/Main.pudu website/src/Render.pudu
pudu test website/src/Test/Website.pudu
pudu run website/src/Main.pudu
```

Open `http://127.0.0.1:8080`. Set `PUDU_SITE_URL` to the public HTTPS origin before a production
build so canonical URLs, Open Graph URLs, robots.txt, and the sitemap agree.

`Main.pudu` owns the local HTTP listener. `Render.pudu` handles one URL and exits for a serverless
runtime. Vercel uses only a thin process adapter; routing, search, HTML, metadata, robots policy,
and the XML sitemap are implemented in Pudu.

## Vercel preview

Build or download `website/bin/pudu-site-server-linux-x64`, then assemble Build Output API v3 with
the intended HTTPS preview origin:

```bash
PUDU_SITE_URL=https://preview.example \
PUDU_STATIC_SERVER=website/bin/pudu-site-server-macos \
website/scripts/build-vercel.sh
vercel deploy --prebuilt
```

Redeploy after replacing the temporary origin with the first preview URL. This keeps every
canonical URL, Open Graph URL, `robots.txt`, and sitemap entry aligned with the tested preview.
