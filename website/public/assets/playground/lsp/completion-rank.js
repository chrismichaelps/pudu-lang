// Ordering an answered completion list by what has been typed since.
//
// Names that start with the typed text as written come first, then names that
// start with it in another case — `gre` wants `greet` before `GREETING` — then
// names that contain its letters in order. Within each group the server's order
// is kept, which puts the nearest names first. An item is matched by its
// `filterText` when it has one — a module path is matched as the whole path —
// and the server's order is its `sortText` when it gives one.

import { MAX_COMPLETIONS_SHOWN } from "../config/constants.js";
import { subsequenceMarks } from "../text/scan.js";

export function usableItems(result) {
  const items = Array.isArray(result) ? result : Array.isArray(result?.items) ? result.items : [];
  const usable = items.filter((item) => typeof item?.label === "string" && item.label.length > 0);
  if (!usable.some((item) => typeof item.sortText === "string")) return usable;
  return usable
    .map((item, position) => ({ item, key: typeof item.sortText === "string" ? item.sortText : item.label, position }))
    .sort((left, right) => (left.key < right.key ? -1 : left.key > right.key ? 1 : left.position - right.position))
    .map(({ item }) => item);
}

function matchedText(item) {
  return typeof item.filterText === "string" ? item.filterText : item.label;
}

// Each shown item with the ranges of its label that match `typed`.
export function rankCompletions(items, typed) {
  const lower = typed.toLowerCase();
  const exact = [];
  const prefixed = [];
  const scattered = [];
  for (const item of items) {
    const matched = matchedText(item);
    const label = matched.toLowerCase();
    // Marks are drawn on the label, so they are kept only when it is what was matched.
    const marked = (marks) => (matched === item.label ? marks : []);
    if (label.startsWith(lower)) {
      const group = matched.startsWith(typed) ? exact : prefixed;
      group.push({ item, marks: marked(typed ? [[0, typed.length]] : []) });
    } else if (lower) {
      const marks = subsequenceMarks(label, lower);
      if (marks) scattered.push({ item, marks: marked(marks) });
    }
  }
  return exact.concat(prefixed, scattered).slice(0, MAX_COMPLETIONS_SHOWN);
}

// Whether a list is only the name already typed, which says nothing new.
export function onlyRepeats(ranked, typed) {
  return ranked.length === 1 && ranked[0].item.label === typed;
}
