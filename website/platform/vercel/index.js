"use strict";

const { spawn } = require("node:child_process");
const http = require("node:http");
const path = require("node:path");

const serverPath = path.join(__dirname, "pudu-site-server");
const cataloguePath = path.join(__dirname, "api.json");
const port = 31947;
let child = null;
let ready = null;

function canonicalOrigin() {
  if (process.env.PUDU_SITE_URL) return process.env.PUDU_SITE_URL.replace(/\/$/, "");
  const host = process.env.VERCEL_PROJECT_PRODUCTION_URL || process.env.VERCEL_URL;
  return host ? `https://${host}` : "http://127.0.0.1:8080";
}

function startServer() {
  if (ready) return ready;
  ready = new Promise((resolve, reject) => {
    child = spawn(serverPath, [], {
      env: {
        ...process.env,
        PUDU_CATALOG_PATH: cataloguePath,
        PUDU_SITE_CONNECTIONS: "0",
        PUDU_SITE_HOST: "127.0.0.1",
        PUDU_SITE_PORT: String(port),
        PUDU_SITE_URL: canonicalOrigin(),
      },
      stdio: ["ignore", "pipe", "pipe"],
    });
    const timer = setTimeout(() => reject(new Error("Pudu server startup timed out")), 55_000);
    child.stdout.on("data", (chunk) => {
      if (String(chunk).includes("Pudu docs listening")) {
        clearTimeout(timer);
        resolve();
      }
    });
    child.once("error", reject);
    child.once("exit", (code) => {
      clearTimeout(timer);
      child = null;
      ready = null;
      if (code && code !== 0) reject(new Error(`Pudu server exited with ${code}`));
    });
  });
  ready.catch(() => {
    if (child) child.kill();
    child = null;
    ready = null;
  });
  return ready;
}

function proxy(target, response) {
  return new Promise((resolve, reject) => {
    const upstream = http.get({ host: "127.0.0.1", port, path: target }, (answer) => {
      response.statusCode = answer.statusCode || 500;
      for (const [name, value] of Object.entries(answer.headers)) {
        if (value !== undefined && !["connection", "content-length", "transfer-encoding"].includes(name)) {
          response.setHeader(name, value);
        }
      }
      answer.pipe(response);
      answer.once("end", resolve);
    });
    upstream.setTimeout(20_000, () => upstream.destroy(new Error("Pudu request timed out")));
    upstream.once("error", reject);
  });
}

module.exports = async (request, response) => {
  const target = typeof request.url === "string" && request.url.startsWith("/")
    ? request.url.slice(0, 8192)
    : "/";
  try {
    await startServer();
    await proxy(target, response);
  } catch {
    response.statusCode = 503;
    response.setHeader("content-type", "text/plain; charset=utf-8");
    response.setHeader("retry-after", "5");
    response.end("Pudu documentation search is starting. Please try again.");
  }
};
