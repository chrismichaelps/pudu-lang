// Requests to the playground's server, each with a deadline that covers the
// whole answer, body included.

import { JSON_HEADERS } from "../config/constants.js";
import { FAILURE, RequestFailure } from "./errors.js";

// Post `body` as JSON and read the JSON answer, whatever its status: the
// playground answers refusals in JSON too. `cancel` withdraws the request.
export function postJson(url, body, { timeoutMs, cancel } = {}) {
  const init = { method: "POST", headers: JSON_HEADERS, body: JSON.stringify(body), credentials: "same-origin" };
  return fetchWithin(url, init, { timeoutMs, cancel }, async (response) => {
    const answer = await response.json().catch(() => null);
    if (!answer || typeof answer !== "object") throw new RequestFailure(FAILURE.unreadable, response.status);
    return { status: response.status, headers: response.headers, answer };
  });
}

// Fetch a page of this site as text.
export function getText(url, { timeoutMs, cancel } = {}) {
  const init = { headers: { accept: "text/html" }, credentials: "same-origin" };
  return fetchWithin(url, init, { timeoutMs, cancel }, (response) => {
    if (!response.ok) throw new RequestFailure(FAILURE.unreadable, response.status);
    return response.text();
  });
}

async function fetchWithin(url, init, { timeoutMs, cancel }, read) {
  const controller = new AbortController();
  let timedOut = false;
  const timer = timeoutMs
    ? setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, timeoutMs)
    : null;
  const withdraw = () => controller.abort();
  cancel?.addEventListener("abort", withdraw, { once: true });
  try {
    return await read(await fetch(url, { ...init, signal: controller.signal }));
  } catch (problem) {
    if (timedOut) throw new RequestFailure(FAILURE.timedOut);
    if (cancel?.aborted) throw new RequestFailure(FAILURE.cancelled);
    if (problem instanceof RequestFailure) throw problem;
    throw new RequestFailure(FAILURE.offline);
  } finally {
    if (timer) clearTimeout(timer);
    cancel?.removeEventListener("abort", withdraw);
  }
}

// The response's `retry-after`, in seconds, or `fallback`.
export function retryAfterSeconds(headers, fallback) {
  const stated = Number(headers?.get("retry-after"));
  return Number.isFinite(stated) && stated > 0 ? stated : fallback;
}
