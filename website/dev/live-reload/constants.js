// What the watched page asks, and how often.

// Where the site says which start of it is serving.
export const STATE_PATH = "/__pudu/reload";

// How long between questions while the site answers, and while it is starting
// again. A quarter of a second is under what a person notices after saving.
export const POLL_MS = 250;
export const RETRY_MS = 150;

// What a change must be to be taken in place rather than by reloading.
export const STYLE_EXTENSION = ".css";
export const RELOAD_PARAMETER = "reload";
