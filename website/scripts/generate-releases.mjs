// Write the download table's data from the published releases.
//
// The page is part of the static graph, so the archives it offers are read once
// here rather than at request time: a reader on the CDN waits for no API, and a
// rate limit or an outage at the forge cannot take the download page down. The
// cost is that a new release reaches the page on the next deployment, which is
// the same trip its announcement takes.
//
// Usage: node generate-releases.mjs [--repository owner/name] [--out path]
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import process from "node:process";

const REPOSITORY = "chrismichaelps/pudu-lang";

// A release names its archives by target. Each one is spelled for a reader here,
// so the table says "macOS" and "Apple silicon" rather than repeating the triple.
const TARGETS = {
  "linux-amd64": { os: "Linux", arch: "x86-64", note: "Intel or AMD 64-bit" },
  "darwin-arm64": { os: "macOS", arch: "ARM64", note: "Apple silicon" },
};

function argument(name, fallback) {
  const at = process.argv.indexOf(name);
  return at >= 0 && process.argv[at + 1] ? process.argv[at + 1] : fallback;
}

async function get(url, accept = "application/vnd.github+json") {
  const headers = { accept, "user-agent": "pudu-website-release-generator" };
  if (process.env.GITHUB_TOKEN) headers.authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  const answer = await fetch(url, { headers });
  if (!answer.ok) throw new Error(`${answer.status} ${answer.statusText} for ${url}`);
  return accept === "application/vnd.github+json" ? answer.json() : answer.text();
}

// Sizes are shown in whole megabytes with one decimal: the exact byte count is
// there for anyone who wants it, and a reader choosing a download does not.
function readableSize(bytes) {
  const megabytes = bytes / 1000 / 1000;
  return `${megabytes.toFixed(1)} MB`;
}

function targetOf(name) {
  for (const target of Object.keys(TARGETS)) {
    if (name.includes(target)) return target;
  }
  return null;
}

async function main() {
  const repository = argument("--repository", REPOSITORY);
  const out = resolve(argument("--out", "website/data/releases.json"));

  const releases = await get(`https://api.github.com/repos/${repository}/releases?per_page=20`);
  const published = releases.filter((release) => !release.draft);
  if (published.length === 0) throw new Error("no published release was found");
  const latest = published[0];

  // The checksum beside each archive is the one the release publishes, fetched
  // rather than recomputed, so the page cannot disagree with the file it offers.
  const checksums = new Map();
  for (const asset of latest.assets) {
    if (!asset.name.endsWith(".sha256")) continue;
    const text = await get(asset.browser_download_url, "text/plain");
    checksums.set(asset.name.replace(/\.sha256$/, ""), text.trim().split(/\s+/)[0]);
  }

  const downloads = [];
  for (const asset of latest.assets) {
    if (!asset.name.endsWith(".tar.gz")) continue;
    const target = targetOf(asset.name);
    if (!target) continue;
    downloads.push({
      os: TARGETS[target].os,
      arch: TARGETS[target].arch,
      note: TARGETS[target].note,
      target,
      file: asset.name,
      bytes: asset.size,
      size: readableSize(asset.size),
      url: asset.browser_download_url,
      checksum: checksums.get(asset.name) ?? "",
    });
  }
  if (downloads.length === 0) throw new Error(`no recognised archives in ${latest.tag_name}`);
  downloads.sort((left, right) => left.os.localeCompare(right.os) || left.arch.localeCompare(right.arch));

  const document = {
    schemaVersion: 1,
    version: latest.tag_name.replace(/^v/, ""),
    tag: latest.tag_name,
    url: latest.html_url,
    published: latest.published_at.slice(0, 10),
    prerelease: Boolean(latest.prerelease),
    releasesUrl: `https://github.com/${repository}/releases`,
    downloads,
  };

  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(document, null, 2) + "\n");
  console.log(`${document.tag}: ${downloads.length} archives -> ${out}`);
}

main().catch((problem) => {
  console.error(problem.message);
  process.exit(1);
});
