"use strict";

const fs = require("node:fs");
const path = require("node:path");

let catalogEntries = null;

function loadCatalog() {
  if (!catalogEntries) {
    let raw;
    const primary = path.join(__dirname, "api.json");
    const fallback = path.join(__dirname, "../../data/api.json");
    if (fs.existsSync(primary)) {
      raw = fs.readFileSync(primary, "utf8");
    } else if (fs.existsSync(fallback)) {
      raw = fs.readFileSync(fallback, "utf8");
    } else {
      throw new Error("api.json catalogue not found");
    }
    const parsed = JSON.parse(raw);
    catalogEntries = parsed.entries || [];
  }
  return catalogEntries;
}

function categoryOf(kind) {
  return kind && kind.startsWith("fn") ? "fn" : kind;
}

function qualifiedName(entry) {
  return `${entry.module}.${entry.name}`;
}

function symbolPath(entry) {
  return `/docs/${encodeURIComponent(entry.module)}/${encodeURIComponent(categoryOf(entry.kind))}/${encodeURIComponent(entry.name)}`;
}

function summaryOf(entry) {
  if (Array.isArray(entry.doc) && entry.doc.length > 0) {
    return entry.doc[0];
  }
  return "";
}

function scoreOf(entry, wanted) {
  const name = (entry.name || "").toLowerCase();
  const moduleName = (entry.module || "").toLowerCase();
  const signature = (entry.signature || "").toLowerCase();
  const qName = qualifiedName(entry).toLowerCase();

  if (name === wanted) return 1000;
  if (qName === wanted) return 980;
  if (name.startsWith(wanted)) return 850;
  if (name.includes(wanted)) return 700;
  if (moduleName === wanted) return 650;
  if (moduleName.includes(wanted)) return 500;
  if (signature.includes(wanted)) return 300;
  if (Array.isArray(entry.doc)) {
    for (const line of entry.doc) {
      if (line.toLowerCase().includes(wanted)) return 100;
    }
  }
  return 0;
}

function search(entries, query, limit = 80) {
  const wanted = query.trim().toLowerCase();
  if (!wanted || limit <= 0) return [];

  const hits = [];
  for (const entry of entries) {
    const score = scoreOf(entry, wanted);
    if (score > 0) {
      hits.push({ entry, score });
    }
  }

  hits.sort((left, right) => {
    if (left.score !== right.score) return right.score - left.score;
    return qualifiedName(left.entry).localeCompare(qualifiedName(right.entry));
  });

  return hits.slice(0, limit);
}

function escapeHtml(str) {
  return String(str || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderResults(query, hits) {
  const heading = query.trim() ? `Results for “${escapeHtml(query)}”` : "Search Pudu";
  const countText = `${hits.length} matching declarations`;

  const rowsHtml = hits.map(hit => {
    const entry = hit.entry;
    const p = symbolPath(entry);
    const qName = qualifiedName(entry);
    const sig = escapeHtml(entry.signature || "");
    const sum = escapeHtml(summaryOf(entry));
    const meta = `${escapeHtml(entry.kind)} · ${escapeHtml(entry.module)}`;

    return `<li class="result">
  <a class="result-name" href="${p}">${escapeHtml(qName)}</a>
  <code class="signature">${sig}</code>
  <p class="summary">${sum}</p>
  <div class="meta">${meta}</div>
</li>`;
  }).join("\n");

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="icon" type="image/png" href="/assets/pudu-lang-short.png" />
  <link rel="stylesheet" href="/assets/site.css?v=5" />
  <title>${heading} | Pudu</title>
  <meta name="description" content="Search results from the Pudu public API catalogue." />
  <meta name="robots" content="noindex,follow" />
</head>
<body>
  <a class="skip" href="#content">Skip to content</a>
  <header class="masthead">
    <div class="masthead-inner">
      <a class="brand" href="/"><img src="/assets/pudu-lang-full-logo.png" alt="Pudu programming language" /></a>
      <form class="search header-search" action="/search" method="get">
        <label for="q" class="skip">Search Pudu APIs</label>
        <input id="q" name="q" type="search" value="${escapeHtml(query)}" placeholder="Search names or types, such as Array[T] -&gt; T" required="required" />
        <button type="submit">Search</button>
      </form>
      <nav class="top-nav" aria-label="Main navigation">
        <a href="/guide">Guide</a>
        <a href="/modules">API</a>
        <a href="/about">About</a>
        <a href="/donate">Donate</a>
        <a class="github-link" href="https://github.com/chrismichaelps/pudu-lang/" rel="external noopener noreferrer" aria-label="GitHub repository">
          <svg class="github-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 .5C5.73.5.64 5.59.64 11.86c0 5.01 3.25 9.26 7.76 10.76.57.1.78-.25.78-.55v-2.17c-3.15.68-3.82-1.34-3.82-1.34-.52-1.31-1.26-1.66-1.26-1.66-1.03-.7.08-.69.08-.69 1.14.08 1.74 1.17 1.74 1.17 1.01 1.74 2.66 1.24 3.31.95.1-.73.4-1.24.72-1.53-2.52-.29-5.17-1.26-5.17-5.59 0-1.23.44-2.24 1.17-3.03-.12-.29-.51-1.44.11-2.99 0 0 .95-.31 3.12 1.16a10.8 10.8 0 0 1 5.68 0c2.17-1.47 3.12-1.16 3.12-1.16.62 1.55.23 2.7.11 2.99.73.79 1.17 1.8 1.17 3.03 0 4.34-2.66 5.3-5.19 5.58.41.35.77 1.04.77 2.1v3.12c0 .3.21.66.78.55a11.38 11.38 0 0 0 7.75-10.76C23.36 5.59 18.27.5 12 .5Z"></path></svg>
        </a>
      </nav>
    </div>
  </header>
  <main id="content" class="shell">
    <div>
      <section class="intro">
        <h1>${heading}</h1>
        <p>${escapeHtml(countText)}</p>
      </section>
      <form class="search home-search" action="/search" method="get">
        <label for="q" class="skip">Search Pudu APIs</label>
        <input id="q" name="q" type="search" value="${escapeHtml(query)}" placeholder="Search names or types, such as Array[T] -&gt; T" required="required" />
        <button type="submit">Search</button>
      </form>
      <ul class="results">
        ${rowsHtml}
      </ul>
    </div>
  </main>
  <footer class="footer">
    <div class="footer-inner">
      <span class="footer-brand"><img src="/assets/pudu-lang-short.png" alt="" /><span>Pudu language documentation</span></span>
      <small>© 2026 Chris M. Pérez Santiago. All rights reserved.</small>
      <span class="footer-links"><a href="/donate">Donate</a><a href="https://github.com/chrismichaelps/pudu-lang/" rel="external noopener noreferrer">GitHub</a></span>
    </div>
  </footer>
</body>
</html>`;
}

module.exports = async (request, response) => {
  try {
    const reqUrl = new URL(request.url || "/", "http://localhost");
    const query = reqUrl.searchParams.get("q") || "";
    const entries = loadCatalog();
    const hits = search(entries, query, 80);
    const html = renderResults(query, hits);

    response.statusCode = 200;
    response.setHeader("content-type", "text/html; charset=utf-8");
    response.setHeader("cache-control", "public, max-age=60, s-maxage=300");
    response.end(html);
  } catch (err) {
    console.error("Vercel search handler error:", err);
    response.statusCode = 500;
    response.setHeader("content-type", "text/plain; charset=utf-8");
    response.end("Internal Server Error");
  }
};
