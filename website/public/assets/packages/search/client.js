import { SUGGEST_PATH } from "./constants.js";

export class SuggestError extends Error {
  constructor(status) {
    super(`Suggestions answered ${status}`);
    this.name = "SuggestError";
  }
}

/**
 * A suggestion reader for one search box. Starting a request aborts the one
 * before it, and an answer that arrives after a newer request resolves to
 * null so it can never replace newer results.
 */
export function suggestionClient() {
  let controller = null;
  let generation = 0;

  function cancel() {
    controller?.abort();
    controller = null;
    generation += 1;
  }

  async function fetchSuggestions(query, filter) {
    cancel();
    const own = new AbortController();
    const mine = generation;
    controller = own;
    const url = new URL(SUGGEST_PATH, location.origin);
    url.searchParams.set("q", query);
    if (filter) url.searchParams.set("filter", filter);
    try {
      const response = await fetch(url, { signal: own.signal, headers: { Accept: "application/json" } });
      if (!response.ok) throw new SuggestError(response.status);
      const body = await response.json();
      return mine === generation ? body : null;
    } catch (error) {
      if (error.name === "AbortError" || mine !== generation) return null;
      throw error;
    }
  }

  return { fetchSuggestions, cancel };
}
