import { readFile, writeFile } from "node:fs/promises";

const [sourcePath, publicPath, targetPath] = process.argv.slice(2);

if (!sourcePath || !publicPath || !targetPath) {
  throw new Error("usage: normalize-catalog.mjs <docs> <public-api> <target>");
}

const document = JSON.parse(await readFile(sourcePath, "utf8"));
const publicApi = JSON.parse(await readFile(publicPath, "utf8"));
if (!Array.isArray(document.entries)) {
  throw new Error("pudu doc index has no entries array");
}
if (!Array.isArray(publicApi.exports)) {
  throw new Error("pudu API index has no exports array");
}

const exported = new Set(publicApi.exports.map((entry) => `${entry.module}\u0000${entry.name}`));

const unique = new Map();
for (const entry of document.entries) {
  if (![entry.module, entry.kind, entry.name].every((value) => typeof value === "string")) continue;
  if (!exported.has(`${entry.module}\u0000${entry.name}`)) continue;
  const normalized = {
    module: entry.module,
    kind: entry.kind,
    name: entry.name,
    signature: typeof entry.signature === "string" ? entry.signature : "",
    doc: Array.isArray(entry.doc) ? entry.doc.filter((line) => typeof line === "string") : [],
  };
  const key = [normalized.module, normalized.kind, normalized.name, normalized.signature].join("\u0000");
  if (!unique.has(key)) unique.set(key, normalized);
}

const entries = [...unique.values()].sort((left, right) =>
  left.module.localeCompare(right.module) ||
  left.name.localeCompare(right.name) ||
  left.kind.localeCompare(right.kind) ||
  left.signature.localeCompare(right.signature),
);

await writeFile(
  targetPath,
  JSON.stringify({ schemaVersion: 1, languageVersion: publicApi.version, entries }) + "\n",
);
