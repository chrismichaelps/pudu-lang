// Write the package pages' data from GitHub.
//
// A package is a public GitHub repository with the topic `pudu-package` and a
// `pudu.toml` naming it `@owner/repo`. Its releases are its tags that read as
// versions (`v1.2.0`); notes, author, and time come from the GitHub release of
// the tag when there is one, and from the tagged commit otherwise. Each
// release's dependencies come from its `pudu.toml`. For the latest release the
// snapshot holds its files (from the commit archive, without dot paths or a
// top-level `deps/`) and an API catalogue built with `pudu doc --json` and
// `pudu api --json`. Owners' profiles and avatars come from GitHub.
//
// Layout under --out:
//   packages.json                       schemaVersion, source, generatedAt, projects, handles
//   files/@owner/name/<version>/<path>  the latest release's files
//   docs/@owner/name.json               the latest release's API catalogue
//   avatars/<login>.<ext>               each owner's avatar image
//
// `GITHUB_TOKEN`, when set, raises GitHub's rate limit. Nothing is written
// when no repository carries the topic.
//
// Usage: node generate-packages.mjs [--api URL] [--out path] [--pudu path]
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import process from "node:process";

const TOPIC = "pudu-package";
const VERSION = /^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$/;
const IMAGE_TYPES = { "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif" };
const DISCUSSION_LIMIT = 100;

function argument(name, fallback) {
  const at = process.argv.indexOf(name);
  return at >= 0 && process.argv[at + 1] ? process.argv[at + 1] : fallback;
}

const api = argument("--api", process.env.PUDU_GITHUB_API || "https://api.github.com").replace(/\/$/, "");
const out = resolve(argument("--out", "website/data/packages"));
const pudu = argument("--pudu", "pudu");
const here = dirname(new URL(import.meta.url).pathname);

async function request(url, accept = "application/vnd.github+json") {
  const headers = { accept, "user-agent": "pudu-website-package-generator", "x-github-api-version": "2022-11-28" };
  if (process.env.GITHUB_TOKEN) headers.authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  const answer = await fetch(url, { headers, redirect: "follow", signal: AbortSignal.timeout(60000) });
  return answer;
}

async function json(path) {
  const answer = await request(api + path);
  if (answer.status === 404) return null;
  if (!answer.ok) throw new Error(`${answer.status} ${answer.statusText} for ${api}${path}`);
  return answer.json();
}

async function pages(path) {
  const found = [];
  for (let page = 1; ; page += 1) {
    const joiner = path.includes("?") ? "&" : "?";
    const batch = await json(`${path}${joiner}per_page=100&page=${page}`);
    const items = Array.isArray(batch) ? batch : batch?.items ?? [];
    found.push(...items);
    if (items.length < 100) return found;
  }
}

function compareVersions(left, right) {
  const a = VERSION.exec(left);
  const b = VERSION.exec(right);
  for (let i = 1; i <= 3; i += 1) {
    if (Number(a[i]) !== Number(b[i])) return Number(a[i]) - Number(b[i]);
  }
  if (!a[4] && b[4]) return 1;
  if (a[4] && !b[4]) return -1;
  return (a[4] ?? "").localeCompare(b[4] ?? "");
}

function manifestOf(text) {
  const manifest = { name: "", version: "", description: "", license: "", root: "", source: "src", keywords: [], dependencies: {} };
  let section = "";
  for (const raw of text.split("\n")) {
    const line = raw.replace(/#.*$/, "").trim();
    const heading = /^\[(.+)\]$/.exec(line);
    if (heading) { section = heading[1].trim(); continue; }
    const pair = /^("?[^"=]+"?)\s*=\s*(.+)$/.exec(line);
    if (!pair) continue;
    const key = pair[1].replaceAll('"', "").trim();
    const value = pair[2].trim();
    const text = /^"(.*)"$/.exec(value)?.[1];
    if (section === "package") {
      if (key === "keywords") manifest.keywords = [...value.matchAll(/"([^"]*)"/g)].map((m) => m[1]);
      else if (text !== undefined && key in manifest) manifest[key] = text;
    } else if (section === "dependencies" && text !== undefined) {
      manifest.dependencies[key] = text;
    }
  }
  return manifest;
}

async function fileAt(owner, repo, path, ref) {
  const found = await json(`/repos/${owner}/${repo}/contents/${path}?ref=${encodeURIComponent(ref)}`);
  return found?.content ? Buffer.from(found.content, "base64").toString("utf8") : null;
}

function packaged(path) {
  return !path.startsWith("deps/") && !path.split("/").some((segment) => segment.startsWith("."));
}

function walk(directory) {
  const found = [];
  for (const name of readdirSync(directory)) {
    const full = join(directory, name);
    if (statSync(full).isDirectory()) found.push(...walk(full));
    else found.push(full);
  }
  return found;
}

async function unpack(owner, repo, commit, directory) {
  const answer = await request(`${api}/repos/${owner}/${repo}/tarball/${commit}`);
  if (!answer.ok) throw new Error(`${answer.status} for the archive of ${owner}/${repo}`);
  const scratch = mkdtempSync(join(tmpdir(), "pudu-package-archive-"));
  try {
    writeFileSync(join(scratch, "archive.tar.gz"), Buffer.from(await answer.arrayBuffer()));
    mkdirSync(join(scratch, "files"));
    execFileSync("tar", ["-xzf", join(scratch, "archive.tar.gz"), "-C", join(scratch, "files"), "--strip-components=1", "--no-same-owner"]);
    const files = [];
    for (const full of walk(join(scratch, "files"))) {
      const path = relative(join(scratch, "files"), full).split("\\").join("/");
      if (!packaged(path)) continue;
      mkdirSync(dirname(join(directory, path)), { recursive: true });
      writeFileSync(join(directory, path), readFileSync(full));
      files.push(path);
    }
    return files.sort();
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

function catalogue(directory, sources, target) {
  if (sources.length === 0) return;
  const scratch = mkdtempSync(join(tmpdir(), "pudu-package-docs-"));
  try {
    const raw = join(scratch, "doc.json");
    const exported = join(scratch, "api.json");
    writeFileSync(raw, execFileSync(pudu, ["doc", "--json", ...sources], { cwd: directory, maxBuffer: 1 << 28 }));
    writeFileSync(exported, execFileSync(pudu, ["api", "--json", ...sources], { cwd: directory, maxBuffer: 1 << 28 }));
    execFileSync("node", [join(here, "normalize-catalog.mjs"), raw, exported, target]);
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

async function avatarOf(owner, url) {
  try {
    const image = await fetch(url, { signal: AbortSignal.timeout(30000) });
    const extension = IMAGE_TYPES[image.headers.get("content-type")?.split(";")[0]?.trim()];
    if (!image.ok || !extension) return "";
    mkdirSync(join(out, "avatars"), { recursive: true });
    writeFileSync(join(out, "avatars", `${owner}.${extension}`), Buffer.from(await image.arrayBuffer()));
    return `/packages/avatars/${owner}.${extension}`;
  } catch {
    return "";
  }
}

async function discussions(owner, repo, kind) {
  const path = kind === "ticket" ? "issues" : "pulls";
  const webPath = kind === "ticket" ? "issues" : "pull";
  const records = [];
  for (let page = 1; page <= 3 && records.length < DISCUSSION_LIMIT; page += 1) {
    const batch = await json(`/repos/${owner}/${repo}/${path}?state=all&sort=updated&direction=desc&per_page=100&page=${page}`);
    if (!Array.isArray(batch)) break;
    for (const item of batch) {
      if (kind === "ticket" && item.pull_request) continue;
      if (!Number.isSafeInteger(item.number) || item.number <= 0) continue;
      records.push({
        number: item.number,
        title: String(item.title ?? "").slice(0, 500),
        body: String(item.body ?? "").slice(0, 50000),
        author: String(item.user?.login ?? ""),
        state: item.merged_at ? "merged" : item.state === "open" ? "open" : "closed",
        createdAt: String(item.created_at ?? ""),
        updatedAt: String(item.updated_at ?? ""),
        comments: Math.max(0, Number(item.comments ?? 0)),
        labels: Array.isArray(item.labels) ? item.labels.slice(0, 12).map((label) => String(label.name ?? "")) : [],
        url: `https://github.com/${owner}/${repo}/${webPath}/${item.number}`,
        draft: kind === "contribution" && item.draft === true,
      });
      if (records.length >= DISCUSSION_LIMIT) break;
    }
    if (batch.length < 100) break;
  }
  return records;
}

async function project(repository) {
  const owner = repository.owner.login.toLowerCase();
  const repo = repository.name.toLowerCase();
  const name = `@${owner}/${repo}`;
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(owner) || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(repo)) return null;
  const tags = (await pages(`/repos/${owner}/${repo}/tags`)).filter((tag) => VERSION.test(tag.name));
  const published = new Map((await pages(`/repos/${owner}/${repo}/releases`)).map((release) => [release.tag_name, release]));
  const releases = [];
  for (const tag of tags) {
    const text = await fileAt(owner, repo, "pudu.toml", tag.commit.sha);
    if (text === null) continue;
    const manifest = manifestOf(text);
    if (manifest.name !== name || manifest.version !== tag.name.replace(/^v/, "")) continue;
    const release = published.get(tag.name);
    let at = release?.published_at ?? "";
    if (!at) at = (await json(`/repos/${owner}/${repo}/commits/${tag.commit.sha}`))?.commit?.committer?.date ?? "";
    releases.push({
      version: tag.name.replace(/^v/, ""),
      publishedAt: at,
      publisher: release?.author?.login?.toLowerCase() ?? "",
      checksum: "",
      size: 0,
      language: "",
      dependencies: manifest.dependencies,
      modules: [],
      notes: release?.body ?? "",
      yanked: false,
      tag: tag.name,
      commit: tag.commit.sha,
      manifest,
    });
  }
  if (releases.length === 0) return null;
  releases.sort((a, b) => compareVersions(a.version, b.version));
  const latest = releases[releases.length - 1];
  const directory = join(out, "files", name, latest.version);
  const files = await unpack(owner, repo, latest.commit, directory);
  const source = latest.manifest.source || "src";
  latest.modules = files.filter((path) => path.startsWith(`${source}/`) && path.endsWith(".pudu")).map((path) => path.slice(source.length + 1, -5).split("/").join("."));
  const readmePath = files.find((path) => /^readme(\.md)?$/i.test(path));
  const docsTarget = join(out, "docs", `${name}.json`);
  mkdirSync(dirname(docsTarget), { recursive: true });
  try {
    catalogue(directory, files.filter((path) => path.endsWith(".pudu") && !/^tests?\//.test(path)), docsTarget);
  } catch (problem) {
    rmSync(docsTarget, { force: true });
    console.warn(`no API reference for ${name}@${latest.version}: ${problem.message}`);
  }
  const searchEntries = existsSync(docsTarget)
    ? JSON.parse(readFileSync(docsTarget, "utf8")).entries.map((entry) => ({ moduleName: entry.module, kind: entry.kind, name: entry.name, signature: entry.signature }))
    : [];
  const words = (value) => value.split("-").map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join("");
  const tickets = await discussions(owner, repo, "ticket");
  const contributions = await discussions(owner, repo, "contribution");
  const discussionTarget = join(out, "discussions", `${name}.json`);
  mkdirSync(dirname(discussionTarget), { recursive: true });
  writeFileSync(discussionTarget, JSON.stringify({ tickets, contributions }) + "\n");
  return {
    name,
    description: latest.manifest.description || repository.description || "",
    keywords: latest.manifest.keywords.length > 0 ? latest.manifest.keywords : (repository.topics ?? []).filter((topic) => topic !== TOPIC),
    license: latest.manifest.license || repository.license?.spdx_id || "",
    visibility: "public",
    root: latest.manifest.root || words(repo),
    readme: readmePath ? readFileSync(join(directory, readmePath), "utf8") : "",
    createdAt: repository.created_at ?? "",
    latest: latest.version,
    head: null,
    unlisted: false,
    repository: repository.html_url,
    stars: repository.stargazers_count ?? 0,
    forks: repository.forks_count ?? 0,
    openIssues: repository.open_issues_count ?? 0,
    searchEntries,
    releases: releases.map(({ manifest, ...release }) => release),
  };
}

async function main() {
  const repositories = (await pages(`/search/repositories?q=${encodeURIComponent(`topic:${TOPIC}`)}&sort=stars`)).filter((repository) => !repository.private && !repository.archived);
  rmSync(out, { recursive: true, force: true });
  if (repositories.length === 0) {
    console.log(`no repository carries the ${TOPIC} topic; no package pages are written`);
    return;
  }
  mkdirSync(out, { recursive: true });
  const projects = [];
  const handles = new Map();
  for (const repository of repositories) {
    const found = await project(repository);
    if (!found) continue;
    projects.push(found);
    const owner = repository.owner.login.toLowerCase();
    if (!handles.has(owner)) {
      const profile = await json(`/users/${owner}`);
      handles.set(owner, {
        handle: `@${owner}`,
        name: profile?.name ?? "",
        avatarUrl: profile?.avatar_url ?? "",
        avatar: profile?.avatar_url ? await avatarOf(owner, profile.avatar_url) : "",
        githubUrl: profile?.html_url ?? `https://github.com/${owner}`,
        kind: profile?.type === "Organization" ? "organization" : "user",
      });
    }
  }
  projects.sort((a, b) => a.name.localeCompare(b.name));
  writeFileSync(
    join(out, "packages.json"),
    JSON.stringify({ schemaVersion: 1, source: `${api} topic:${TOPIC}`, generatedAt: new Date().toISOString(), projects, handles: [...handles.values()] }, null, 2) + "\n",
  );
  console.log(`wrote ${projects.length} packages from GitHub into ${out}`);
}

main().catch((problem) => {
  console.error(problem.message);
  process.exit(1);
});
