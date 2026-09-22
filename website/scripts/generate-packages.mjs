// Write the package pages' data from a package registry.
//
// Reads every public project the registry lists, and for each writes its
// document, its owner's profile and avatar, the files of its latest release,
// and an API catalogue of those files built with `pudu doc --json` and
// `pudu api --json`, in the catalogue format the standard library's pages
// read. Nothing is written when the registry lists no projects.
//
// Layout under --out:
//   packages.json                       schemaVersion, registry, generatedAt, projects, handles
//   files/@owner/name/<version>/<path>  the latest release's files
//   docs/@owner/name.json               the latest release's API catalogue
//   avatars/<login>                     each owner's avatar image
//
// Usage: node generate-packages.mjs --registry URL [--out path] [--pudu path]
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import process from "node:process";

function argument(name, fallback) {
  const at = process.argv.indexOf(name);
  return at >= 0 && process.argv[at + 1] ? process.argv[at + 1] : fallback;
}

const registry = argument("--registry", process.env.PUDU_REGISTRY || "https://packages.pudu-lang.org").replace(/\/$/, "");
const out = resolve(argument("--out", "website/data/packages"));
const pudu = argument("--pudu", "pudu");
const here = dirname(new URL(import.meta.url).pathname);

async function get(path, kind = "json") {
  const answer = await fetch(registry + path, {
    headers: { accept: "application/json", "user-agent": "pudu-website-package-generator" },
    signal: AbortSignal.timeout(30000),
  });
  if (!answer.ok) throw new Error(`${answer.status} ${answer.statusText} for ${registry}${path}`);
  return kind === "json" ? answer.json() : Buffer.from(await answer.arrayBuffer());
}

function safeName(name) {
  if (!/^@[a-z0-9]+(?:-[a-z0-9]+)*\/[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name)) {
    throw new Error(`invalid public package name: ${name}`);
  }
  return name;
}

function safeFile(path) {
  if (typeof path !== "string" || path.startsWith("-") || path.startsWith("/") || path.includes("\\") ||
      path.split("/").some((segment) => segment === "" || segment === "." || segment === "..")) {
    throw new Error(`invalid package file path: ${path}`);
  }
  return path;
}

function address(path) {
  return path.split("/").map((segment) => encodeURIComponent(segment).replaceAll("%40", "@")).join("/");
}

async function everyProject() {
  const names = [];
  for (let page = 1; ; page += 1) {
    const found = await get(`/api/v1/packages?page=${page}`);
    names.push(...found.projects.map((project) => safeName(project.name)));
    if (page * found.pageSize >= found.total) return names;
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

async function main() {
  const names = await everyProject();
  if (names.length === 0) {
    rmSync(out, { recursive: true, force: true });
    console.log(`${registry} lists no projects; no package pages are written`);
    return;
  }
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  const projects = [];
  const handles = new Map();
  for (const name of names) {
    const document = await get(`/api/v1/packages/${address(name)}`);
    if (document.name !== name || document.visibility !== "public") throw new Error(`invalid public project: ${name}`);
    projects.push(document);
    const owner = name.split("/")[0];
    if (!handles.has(owner)) {
      const profile = await get(`/api/v1/handles/${address(owner)}`);
      delete profile.projects;
      if (profile.avatarUrl) {
        try {
          const image = await fetch(profile.avatarUrl);
          const type = image.headers.get("content-type")?.split(";")[0]?.trim();
          const extension = { "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif" }[type];
          if (image.ok && extension) {
            const login = owner.slice(1);
            mkdirSync(join(out, "avatars"), { recursive: true });
            writeFileSync(join(out, "avatars", `${login}.${extension}`), Buffer.from(await image.arrayBuffer()));
            profile.avatar = `/packages/avatars/${login}.${extension}`;
          }
        } catch {
          // An avatar that cannot be fetched leaves the profile without one.
        }
      }
      handles.set(owner, profile);
    }
    if (!document.latest) continue;
    const version = document.latest;
    const listed = await get(`/api/v1/packages/${address(name)}/releases/${encodeURIComponent(version)}/files`);
    const directory = join(out, "files", name, version);
    const paths = listed.files.map(safeFile);
    let next = 0;
    async function copyFiles() {
      while (next < paths.length) {
        const path = paths[next++];
        const target = join(directory, path);
        const bytes = await get(`/api/v1/packages/${address(name)}/releases/${encodeURIComponent(version)}/files/${address(path)}`, "bytes");
        mkdirSync(dirname(target), { recursive: true });
        writeFileSync(target, bytes);
      }
    }
    await Promise.all(Array.from({ length: Math.min(8, paths.length) }, copyFiles));
    const sources = paths.filter((path) => path.endsWith(".pudu") && !path.startsWith("test/") && !path.startsWith("tests/"));
    mkdirSync(join(out, "docs", owner), { recursive: true });
    const docsTarget = join(out, "docs", `${name}.json`);
    try {
      catalogue(directory, sources, docsTarget);
    } catch (problem) {
      rmSync(docsTarget, { force: true });
      console.warn(`no API reference for ${name}@${version}: ${problem.message}`);
    }
  }
  writeFileSync(
    join(out, "packages.json"),
    JSON.stringify({ schemaVersion: 1, registry, generatedAt: new Date().toISOString(), projects, handles: [...handles.values()] }, null, 2) + "\n",
  );
  console.log(`wrote ${projects.length} projects from ${registry} into ${out}`);
}

main().catch((problem) => {
  console.error(problem.message);
  process.exit(1);
});
