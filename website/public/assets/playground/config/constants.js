// Every tuning value and fixed vocabulary the playground uses, named once.

// The island the page renders the editor in.
export const ISLAND_NAME = "playground";

export const INDENT = "  ";
export const TAB_WIDTH = 2;

export const BRACKET_PAIRS = Object.freeze({ "(": ")", "[": "]", "{": "}", '"': '"' });
export const CLOSERS = new Set(Object.values(BRACKET_PAIRS));

export const DIAGNOSTICS_DELAY_MS = 450;
export const COMPLETION_DELAY_MS = 60;
export const HOVER_DELAY_MS = 350;
export const HOVER_HIDE_GRACE_MS = 180;
export const BLUR_GRACE_MS = 150;

export const ASSIST_TIMEOUT_MS = 15000;
export const RUN_TIMEOUT_MARGIN_MS = 30000;
export const EXAMPLE_TIMEOUT_MS = 15000;
export const FAILURES_BEFORE_PAUSE = 3;
export const ASSIST_PAUSE_MS = 30000;
export const DEFAULT_RETRY_SECONDS = 10;

export const DEFAULT_SHARE_LIMIT = 8000;
export const DEFAULT_RUN_MILLIS = 10000;

export const MAX_COMPLETIONS_SHOWN = 100;
export const COMPLETION_PAGE_ROWS = 8;

export const SPLIT = Object.freeze({ storageKey: "pudu-playground-split", min: 25, max: 80, fallback: 60, step: 5 });

// The protocol's numbers for what a completion is, as the list names them.
export const COMPLETION_KIND_NAMES = Object.freeze({
  1: "text", 2: "method", 3: "function", 4: "constructor", 5: "field", 6: "variable", 7: "type",
  8: "trait", 9: "module", 10: "property", 13: "enum", 14: "keyword", 20: "variant", 21: "constant",
  22: "type", 25: "type",
});
export const CALLABLE_KINDS = new Set([2, 3, 4]);

export const SEVERITY_ERROR = 1;

// The questions the playground's assist endpoint answers.
export const ASSIST = Object.freeze({
  diagnostics: "diagnostics",
  completion: "completion",
  hover: "hover",
  signatureHelp: "signatureHelp",
});

export const ACTION = Object.freeze({ run: "run", format: "format" });

export const OUTCOME = Object.freeze({
  finished: "finished",
  timedOut: "timedOut",
  formatted: "formatted",
  answered: "answered",
});

export const MODIFIER_KEYS = new Set(["Shift", "Control", "Alt", "Meta"]);
export const CARET_KEYS = new Set(["ArrowLeft", "ArrowRight", "Home", "End"]);

export const JSON_HEADERS = Object.freeze({ "content-type": "application/json", accept: "application/json" });
export const HTTP_TOO_MANY = 429;
export const HTTP_SERVER_ERROR = 500;

// A diagnostic's place in a stream the compiler wrote: `Main.pudu:4:7`.
export const PLACE_PATTERN = /([A-Za-z0-9_./-]+\.pudu):(\d+):(\d+)/g;
