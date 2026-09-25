// The completion list: a list box beside the caret, and the documentation of
// the chosen entry beside it.

import { COMPLETION_KIND_NAMES } from "../config/constants.js";
import { MESSAGES } from "../config/messages.js";
import { documentationText, markdownNodes } from "../dom/markdown.js";
import { createFloating, placeFloating } from "../dom/floating.js";
import { element } from "../dom/nodes.js";

const LIST_ID = "playground-completion";

export function createCompletionList({ source, signal, onPick }) {
  const node = createFloating("playground-completion", signal, "presentation");
  const list = element("ul");
  list.id = LIST_ID;
  list.setAttribute("role", "listbox");
  list.setAttribute("aria-label", MESSAGES.suggestions);
  const details = element("div", "completion-details");
  details.hidden = true;
  node.append(list, details);
  node.addEventListener("mousedown", (event) => event.preventDefault());
  source.setAttribute("role", "combobox");
  source.setAttribute("aria-autocomplete", "list");
  source.setAttribute("aria-controls", LIST_ID);
  source.setAttribute("aria-expanded", "false");

  let shown = [];
  let selected = 0;

  function row({ item, marks }, index) {
    const entry = element("li");
    entry.id = `${LIST_ID}-${index}`;
    entry.setAttribute("role", "option");
    entry.append(labelWithMarks(item.label, marks), element("span", "completion-kind", COMPLETION_KIND_NAMES[item.kind] ?? ""));
    entry.addEventListener("mousedown", (event) => {
      event.preventDefault();
      onPick(index);
    });
    entry.addEventListener("mousemove", () => {
      if (selected !== index) select(index, false);
    });
    return entry;
  }

  function select(index, scroll = true) {
    selected = index;
    Array.from(list.children).forEach((entry, position) => entry.setAttribute("aria-selected", String(position === index)));
    const entry = list.children[index];
    if (!entry) return;
    if (scroll) entry.scrollIntoView({ block: "nearest" });
    source.setAttribute("aria-activedescendant", entry.id);
    describe(shown[index]?.item);
  }

  function describe(item) {
    const parts = [];
    if (item?.detail && item.detail !== COMPLETION_KIND_NAMES[item.kind]) {
      parts.push(element("code", "completion-detail", `${item.label}: ${item.detail}`));
    }
    const documentation = documentationText(item?.documentation);
    if (documentation) parts.push(...markdownNodes(documentation));
    details.replaceChildren(...parts);
    details.hidden = parts.length === 0;
  }

  return {
    get open() {
      return !node.hidden;
    },
    get selected() {
      return selected;
    },
    get count() {
      return shown.length;
    },
    itemAt: (index) => shown[index]?.item,
    show(ranked, x, below, above) {
      shown = ranked;
      list.replaceChildren(...ranked.map(row));
      select(0);
      placeFloating(node, x, below, above);
      source.setAttribute("aria-expanded", "true");
    },
    select,
    hide() {
      node.hidden = true;
      shown = [];
      source.setAttribute("aria-expanded", "false");
      source.removeAttribute("aria-activedescendant");
    },
  };
}

function labelWithMarks(label, marks) {
  const name = element("span", "completion-label");
  let at = 0;
  for (const [start, end] of marks) {
    if (start > at) name.append(label.slice(at, start));
    name.append(element("mark", "", label.slice(start, end)));
    at = end;
  }
  name.append(label.slice(at));
  return name;
}
