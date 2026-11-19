// A local server for the Remote app's simulator run. It writes its port, then
// after every request how often each path was asked and how many requests
// were revalidated, to the file named by its argument.
//
// /profile answers 200 with an ETag, and 304 to a request that sends it back.
// /limited answers 429 with Retry-After: 1 once, then 200.
import { createServer } from "node:http";
import { writeFileSync } from "node:fs";

const [record] = process.argv.slice(2);
const counts = { port: 0, profile: 0, limited: 0, revalidated: 0 };

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
