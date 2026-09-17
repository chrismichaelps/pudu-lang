// Ordering an answered completion list by what has been typed since.
//
// Names that start with the typed text as written come first, then names that
// start with it in another case — `gre` wants `greet` before `GREETING` — then
// names that contain its letters in order. Within each group the server's order
// is kept, which puts the nearest names first.

import { MAX_COMPLETIONS_SHOWN } from "../config/constants.js";
import { subsequenceMarks } from "../text/scan.js";

export function usableItems(result) {
  const items = Array.isArray(result) ? result : Array.isArray(result?.items) ? result.items : [];
  return items.filter((item) => typeof item?.label === "string" && item.label.length > 0);
}

// Each shown item with the ranges of its label that match `typed`.
export function rankCompletions(items, typed) {
  const lower = typed.toLowerCase();
  const exact = [];
  const prefixed = [];
  const scattered = [];
  for (const item of items) {
    const label = item.label.toLowerCase();
    if (label.startsWith(lower)) {
      const group = item.label.startsWith(typed) ? exact : prefixed;
      group.push({ item, marks: typed ? [[0, typed.length]] : [] });
    } else if (lower) {
      const marks = subsequenceMarks(label, lower);
      if (marks) scattered.push({ item, marks });
    }
  }
  return exact.concat(prefixed, scattered).slice(0, MAX_COMPLETIONS_SHOWN);
}

// Whether a list is only the name already typed, which says nothing new.
export function onlyRepeats(ranked, typed) {
  return ranked.length === 1 && ranked[0].item.label === typed;
}
