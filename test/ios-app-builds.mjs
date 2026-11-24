import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { availableParallelism, homedir } from "node:os";
import { dirname, join, relative } from "node:path";

/* The iOS suite's app builds: every example the run needs is built before it
   is launched, several at a time in the background, into a cache keyed by
   the content of everything the build reads. An example whose compiler,
   standard library, source, manifest and assets are unchanged is never
   rebuilt across runs. */

const cacheRoot = process.env.PUDU_IOS_CACHE || join(homedir(), "Library", "Caches", "pudu-ios-suite");
// Builds are CPU-bound; one core is left for the simulator and the suite.
const concurrency = Math.max(1, Math.min(Number(process.env.PUDU_IOS_BUILD_JOBS) || 4, availableParallelism() - 1));

// Every file under `path` in name order, each as its relative path and bytes.
function hashTree(hash, root, path) {
  if (!existsSync(path)) return;
  if (statSync(path).isDirectory()) {
    for (const entry of readdirSync(path).sort()) {
      if (!entry.startsWith(".")) hashTree(hash, root, join(path, entry));
    }
    return;
  }
  hash.update(relative(root, path));
  hash.update(readFileSync(path));
}

/* The manifest a build reads: the nearest pudu.toml from the source's folder
   up to the repository. */
function manifestOf(repository, folder) {
  for (let at = folder; at.startsWith(repository); at = dirname(at)) {
    if (existsSync(join(at, "pudu.toml"))) return join(at, "pudu.toml");
    if (at === repository) break;
  }
  return null;
}

/* Starts building `entries`, each `{ key, source }`, and answers a function
   that waits for one entry's app and returns its path. */
export function prebuild(repository, compiler, library, entries) {
  const base = createHash("sha256");
  base.update(readFileSync(compiler));
  hashTree(base, library, library);
  const prefix = base.digest("hex");
  const builds = new Map();
  const pending = [];
  for (const { key, source } of entries) {
    const hash = createHash("sha256").update(prefix).update(readFileSync(source));
    const manifest = manifestOf(repository, dirname(source));
    if (manifest) hash.update(readFileSync(manifest));
    hashTree(hash, dirname(source), join(dirname(source), "assets"));
    const folder = join(cacheRoot, hash.digest("hex").slice(0, 32));
    const name = source.split("/").pop().replace(/\.pudu$/u, "");
    const build = { folder, app: join(folder, `${name}.app`), log: join(folder, "build.log") };
    builds.set(key, build);
    if (existsSync(join(folder, "ok"))) continue;
    rmSync(folder, { recursive: true, force: true });
    mkdirSync(folder, { recursive: true });
    pending.push([source, build.app, folder]);
  }
  if (pending.length > 0) {
    // One background shell runs the builds through xargs's pool; each leaves
    // "ok" or "failed" beside its log, which the waiting step reads.
    const jobs = join(cacheRoot, `jobs-${process.pid}.txt`);
    mkdirSync(cacheRoot, { recursive: true });
    writeFileSync(jobs, pending.map((job) => job.join("\n")).join("\n") + "\n");
    const script = `tr '\\n' '\\0' < "$1" | xargs -0 -n 3 -P ${concurrency} sh -c `
      + `'"$0" build "$1" --native --target ios-simulator-arm64 --app -o "$2" > "$3/build.log" 2>&1 && touch "$3/ok" || touch "$3/failed"' "$2"; rm -f "$1"`;
    spawn("sh", ["-c", script, "sh", jobs, compiler], { stdio: "ignore", detached: true, env: process.env }).unref();
  }
  const pause = new Int32Array(new SharedArrayBuffer(4));
  return function built(key, timeout) {
    const build = builds.get(key);
    if (build === undefined) throw new Error(`no build was started for ${key}`);
    for (let waited = 0; waited < timeout; waited += 200) {
      if (existsSync(join(build.folder, "ok"))) return build.app;
      if (existsSync(join(build.folder, "failed"))) throw new Error(`${key} did not build:\n${readFileSync(build.log, "utf8")}`);
      Atomics.wait(pause, 0, 0, 200);
    }
    throw new Error(`${key} did not build within ${timeout} ms`);
  };
}
