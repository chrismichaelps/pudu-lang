// A local server for the Remote app's simulator run. It writes its port, then
// after every request how often each path was asked and how many requests
// were revalidated, to the file named by its argument.
//
// /profile answers 200 with an ETag, and 304 to a request that sends it back.
// /limited answers 429 with Retry-After: 1 once, then 200.
// /photo.png answers a PNG; /slow.png answers the same PNG after 1.5 seconds,
// so an image retargeted before then must never show it.
import { createServer } from "node:http";
import { readFileSync, writeFileSync } from "node:fs";

const [record] = process.argv.slice(2);
const counts = { port: 0, profile: 0, limited: 0, revalidated: 0, photo: 0, slow: 0 };
const photo = readFileSync(new URL("../website/public/assets/pudu-lang-icon-96.png", import.meta.url));

const server = createServer((request, response) => {
  if (request.url === "/profile") {
    counts.profile += 1;
    if (request.headers["if-none-match"] === '"v1"') {
      counts.revalidated += 1;
      response.writeHead(304, { ETag: '"v1"' });
      response.end();
    } else {
      response.writeHead(200, { "Content-Type": "text/plain", ETag: '"v1"', "Cache-Control": "no-cache" });
      response.end("profile body");
    }
  } else if (request.url === "/limited") {
    counts.limited += 1;
    if (counts.limited === 1) {
      response.writeHead(429, { "Content-Type": "text/plain", "Retry-After": "1" });
      response.end("slow down");
    } else {
      response.writeHead(200, { "Content-Type": "text/plain" });
      response.end("limited body");
    }
  } else if (request.url === "/photo.png") {
    counts.photo += 1;
    response.writeHead(200, { "Content-Type": "image/png", "Cache-Control": "max-age=60" });
    response.end(photo);
  } else if (request.url === "/slow.png") {
    counts.slow += 1;
    setTimeout(() => {
      response.writeHead(200, { "Content-Type": "image/png" });
      response.end(photo);
    }, 1500);
  } else {
    response.writeHead(404);
    response.end();
  }
  writeFileSync(record, JSON.stringify(counts));
});

server.listen(0, "127.0.0.1", () => {
  counts.port = server.address().port;
  writeFileSync(record, JSON.stringify(counts));
});
