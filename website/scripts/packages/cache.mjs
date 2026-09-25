// What one snapshot build keeps for the next: stored API answers, each tag
// commit's manifest, and a copy of the previous output to reuse unchanged
// packages from. A missing or unreadable cache means a full build.
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return fallback;
  }
}

/** A stable digest of what decides a package's releases: its version tags and GitHub releases. */
export function releaseKey(tags, published) {
  const facts = {
    tags: tags.map((tag) => [tag.name, tag.commit?.sha ?? ""]).sort(),
    releases: published.map((release) => [release.tag_name, release.published_at ?? "", release.body ?? "", release.author?.login ?? ""]).sort(),
  };
  return createHash("sha256").update(JSON.stringify(facts)).digest("hex");
}

export function openCache(directory) {
  const snapshot = join(directory, "snapshot");
  const etags = readJson(join(directory, "etags.json"), {});
  const manifests = readJson(join(directory, "manifests.json"), {});
  const keys = readJson(join(directory, "keys.json"), {});
  const previousDocument = readJson(join(snapshot, "packages.json"), { projects: [], handles: [] });
  const projects = new Map((previousDocument.projects ?? []).map((project) => [project.name, project]));
  const handles = new Map((previousDocument.handles ?? []).map((handle) => [handle.handle, handle]));
  const nextKeys = {};

  /** Copies a path of the previous output into `out`; false when the previous build lacks it. */
  function carry(relativePath, out) {
    const from = join(snapshot, relativePath);
    if (!existsSync(from)) return false;
    const to = join(out, relativePath);
    mkdirSync(dirname(to), { recursive: true });
    cpSync(from, to, { recursive: true });
    return true;
  }

  function save(out) {
    mkdirSync(directory, { recursive: true });
    writeFileSync(join(directory, "etags.json"), JSON.stringify(etags));
    writeFileSync(join(directory, "manifests.json"), JSON.stringify(manifests));
    writeFileSync(join(directory, "keys.json"), JSON.stringify(nextKeys));
    rmSync(snapshot, { recursive: true, force: true });
    if (existsSync(out)) cpSync(out, snapshot, { recursive: true });
  }

  return {
    etags,
    manifests,
    previous: (name) => projects.get(name) ?? null,
    previousHandle: (handle) => handles.get(handle) ?? null,
    unchanged: (name, key) => keys[name] === key && projects.has(name),
    remember: (name, key) => { nextKeys[name] = key; },
    carry,
    save,
  };
}
