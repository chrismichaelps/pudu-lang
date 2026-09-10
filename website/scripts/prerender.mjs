import { spawn } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const [serverPath, cataloguePath, outputPath] = process.argv.slice(2);
const siteUrl = process.env.PUDU_SITE_URL?.replace(/\/$/, "");
if (!serverPath || !cataloguePath || !outputPath || !siteUrl) {
  throw new Error("usage: PUDU_SITE_URL=https://host prerender.mjs <server> <catalogue> <output>");
}

const document = JSON.parse(await readFile(cataloguePath, "utf8"));
const modules = [...new Set(document.entries.map((entry) => entry.module))].sort();
const routes = ["/", "/guide", "/about", "/donate", "/modules", "/robots.txt", "/sitemap.xml"];
for (const moduleName of modules) routes.push(`/module/${encodeURIComponent(moduleName)}`);
const symbolRoutes = new Set();
for (const entry of document.entries) {
  const category = entry.kind.startsWith("fn") ? "fn" : entry.kind;
  symbolRoutes.add(`/docs/${encodeURIComponent(entry.module)}/${encodeURIComponent(category)}/${encodeURIComponent(entry.name)}`);
}
routes.push(...symbolRoutes);

const port = 31883;
const server = spawn(serverPath, [], {
  env: {
    ...process.env,
    PUDU_CATALOG_PATH: cataloguePath,
    PUDU_SITE_CONNECTIONS: "0",
    PUDU_SITE_HOST: "127.0.0.1",
    PUDU_SITE_PORT: String(port),
    PUDU_SITE_URL: siteUrl,
  },
  stdio: ["ignore", "pipe", "inherit"],
});

await new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error("Pudu prerender server startup timed out")), 180_000);
  server.stdout.on("data", (chunk) => {
    if (String(chunk).includes("Pudu docs listening")) {
      clearTimeout(timer);
      resolve();
    }
  });
  server.once("error", reject);
  server.once("exit", (code) => reject(new Error(`Pudu prerender server exited with ${code}`)));
});

function destination(route) {
  if (route === "/") return path.join(outputPath, "index.html");
  if (route === "/robots.txt" || route === "/sitemap.xml") return path.join(outputPath, route.slice(1));
  return path.join(outputPath, route.slice(1), "index.html");
}

async function capture(route) {
  const response = await fetch(`http://127.0.0.1:${port}${route}`);
  if (!response.ok) throw new Error(`${route} returned ${response.status}`);
  const target = destination(route);
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, await response.text());
}

try {
  const pending = [...routes];
  const workers = Array.from({ length: 12 }, async () => {
    while (pending.length > 0) await capture(pending.shift());
  });
  await Promise.all(workers);
  process.stdout.write(`Prerendered ${routes.length} Pudu routes\n`);
} finally {
  server.kill("SIGTERM");
}
