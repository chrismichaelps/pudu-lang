# Privacy

This site does not track you.

## What it does not do

- **No analytics.** There is no Google Analytics, no Plausible, no Fathom, no Segment, and no
  telemetry of any kind.
- **No cookies.** The site sets none, so there is no consent banner to dismiss.
- **No third-party scripts.** The pages carry no executable JavaScript at all. The only `<script>`
  tag on a page holds structured data for search engines, which is data rather than code.
- **No accounts.** There is nothing to sign in to and no form that asks who you are.
- **No fonts or assets from anyone else.** The typeface is served from this site, so loading a page
  does not tell another company that you read it.

You can check all of this. Open the page source, or read
[the code that renders it](https://github.com/chrismichaelps/pudu-lang/tree/dev/website) — this site
is a Pudu program, and every page it can serve is in that directory.

## What is unavoidable

The site is hosted on Vercel, and a request has to reach a server to be answered. Vercel keeps
operational logs for that, which include your IP address, and its own privacy policy governs them.
Nothing in those logs is read, analysed, or exported by this project.

The documentation search runs on the server, so a search query reaches it in the URL. Queries are not
stored by this project and are not associated with anything.

## Downloads

Archives are hosted on GitHub Releases. Downloading one is a request to GitHub, and GitHub's privacy
policy applies to it. The compiler itself sends nothing anywhere: `pudu` makes no network request
unless the program you run makes one.

## Changes

If this ever stops being true, this page changes first and the change is visible in the repository's
history.

Questions about this page can go to <chrisperezsantiago1@gmail.com>.
