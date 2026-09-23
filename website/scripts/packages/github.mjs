// The snapshot generator's only connection to GitHub. JSON reads are
// conditional: a stored ETag is sent with each request, and a 304 answer
// reuses the stored body without spending rate limit.
import process from "node:process";

const JSON_TYPE = "application/vnd.github+json";
const TIMEOUT_MILLIS = 60000;
const LONGEST_WAIT_MILLIS = 90000;

function sleep(millis) {
  return new Promise((resolve) => setTimeout(resolve, millis));
}

/**
 * A client for one API origin. `stored` maps each URL to `{ etag, body }` and
 * is updated in place, so the caller can save it for the next build.
 */
export function githubClient(api, stored = {}) {
  const counts = { requests: 0, notModified: 0, archives: 0 };
  let remaining = Infinity;

  function headers(accept) {
    const found = { accept, "user-agent": "pudu-website-package-generator", "x-github-api-version": "2022-11-28" };
    if (process.env.GITHUB_TOKEN) found.authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    return found;
  }

  function track(answer) {
    const header = answer.headers.get("x-ratelimit-remaining");
    if (header === null || answer.headers.get("x-ratelimit-resource") === "search") return;
    const left = Number(header);
    if (Number.isFinite(left)) remaining = left;
  }

  async function send(url, extra = {}, accept = JSON_TYPE) {
    counts.requests += 1;
    const answer = await fetch(url, { headers: { ...headers(accept), ...extra }, redirect: "follow", signal: AbortSignal.timeout(TIMEOUT_MILLIS) });
    track(answer);
    return answer;
  }

  async function json(path) {
    const url = api + path;
    const known = stored[url];
    let answer = await send(url, known?.etag ? { "if-none-match": known.etag } : {});
    if ((answer.status === 403 || answer.status === 429) && answer.headers.get("x-ratelimit-remaining") === "0") {
      const wait = Number(answer.headers.get("x-ratelimit-reset")) * 1000 - Date.now();
      if (wait > 0 && wait < LONGEST_WAIT_MILLIS) {
        await sleep(wait + 1000);
        answer = await send(url, known?.etag ? { "if-none-match": known.etag } : {});
      }
    }
    if (answer.status === 304 && known) {
      counts.notModified += 1;
      return known.body;
    }
    if (answer.status === 404) return null;
    if (!answer.ok) throw new Error(`${answer.status} ${answer.statusText} for ${url}`);
    const body = await answer.json();
    const etag = answer.headers.get("etag");
    if (etag) stored[url] = { etag, body };
    return body;
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

  async function archive(path) {
    counts.archives += 1;
    return send(api + path, {}, JSON_TYPE);
  }

  return {
    json,
    pages,
    archive,
    counts,
    stored,
    remaining: () => remaining,
  };
}
