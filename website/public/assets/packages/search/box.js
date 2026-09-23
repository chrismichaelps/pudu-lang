import { suggestionClient } from "./client.js";
import {
  BOX_CLASS,
  CHIP_CLASS,
  DEBOUNCE_MILLIS,
  FIXED_FILTER_ATTRIBUTE,
  HELP_WIDTH,
  MESSAGES,
  SELECTED_CLASS,
  SCOPED_WIDTH,
  SERVER_CHIP_SELECTOR,
  STATUS_CLASS,
} from "./constants.js";
import { placeBelow } from "./place.js";
import { suggestionList, summary } from "./view.js";

let boxCount = 0;

/**
 * Turns one package search form into a combobox with a suggestion box. The
 * form still submits to the full results page when nothing is selected.
 */
export function bindSearchBox(form) {
  const input = form.querySelector('input[name="q"]');
  if (!input) return;
  const fixed = form.hasAttribute(FIXED_FILTER_ATTRIBUTE);
  const client = suggestionClient();
  const listId = `package-suggest-${++boxCount}`;
  let filter = form.querySelector('input[name="filter"]')?.value || "";
  let rows = [];
  let selected = -1;
  let timer = 0;

  const box = document.createElement("div");
  box.className = BOX_CLASS;
  box.hidden = true;
  const status = document.createElement("p");
  status.className = STATUS_CLASS;
  status.setAttribute("role", "status");
  status.setAttribute("aria-live", "polite");
  form.append(box, status);

  input.setAttribute("role", "combobox");
  input.setAttribute("aria-autocomplete", "list");
  input.setAttribute("aria-controls", listId);
  input.setAttribute("aria-expanded", "false");
  form.querySelector(SERVER_CHIP_SELECTOR)?.remove();

  const help = form.querySelector(".package-search-help");
  const helpPanel = help?.querySelector(".package-search-help-panel");

  function place() {
    if (!box.hidden) placeBelow(box, form, fixed ? { width: Math.max(form.offsetWidth, SCOPED_WIDTH), align: "right" } : {});
    if (help?.open && helpPanel) placeBelow(helpPanel, help, { width: HELP_WIDTH, align: "right" });
  }

  function open() {
    box.hidden = false;
    place();
    form.classList.add("is-suggesting");
    input.setAttribute("aria-expanded", "true");
  }

  function close() {
    client.cancel();
    clearTimeout(timer);
    box.hidden = true;
    form.classList.remove("is-suggesting");
    input.setAttribute("aria-expanded", "false");
    input.removeAttribute("aria-activedescendant");
    selected = -1;
  }

  function select(index) {
    rows[selected]?.classList.remove(SELECTED_CLASS);
    rows[selected]?.setAttribute("aria-selected", "false");
    if (!rows.length) {
      selected = -1;
      return;
    }
    selected = (index + rows.length) % rows.length;
    const row = rows[selected];
    row.classList.add(SELECTED_CLASS);
    row.setAttribute("aria-selected", "true");
    input.setAttribute("aria-activedescendant", row.id);
    row.scrollIntoView({ block: "nearest" });
  }

  function forgetSelection() {
    rows[selected]?.classList.remove(SELECTED_CLASS);
    rows[selected]?.setAttribute("aria-selected", "false");
    selected = -1;
    input.removeAttribute("aria-activedescendant");
  }

  function show(message, state) {
    forgetSelection();
    box.dataset.state = state;
    box.replaceChildren(Object.assign(document.createElement("p"), { className: "package-suggest-message", textContent: message }));
    rows = [];
    selected = -1;
    status.textContent = message;
    open();
  }

  async function load() {
    const query = input.value.trim();
    if (!query && !filter) return close();
    box.dataset.state = "loading";
    status.textContent = MESSAGES.loading;
    try {
      const answer = await client.fetchSuggestions(query, filter);
      if (!answer) return;
      const built = suggestionList(answer, query, listId);
      if (!built.rows.length) return show(MESSAGES.empty, "empty");
      rows = built.rows;
      box.dataset.state = "loaded";
      selected = -1;
      input.removeAttribute("aria-activedescendant");
      box.replaceChildren(built.list);
      status.textContent = summary(answer);
      open();
    } catch {
      show(MESSAGES.failed, "error");
    }
  }

  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(load, DEBOUNCE_MILLIS);
  }

  function renderChip() {
    form.querySelector(`.${CHIP_CLASS}`)?.remove();
    let field = form.querySelector('input[name="filter"]');
    if (!filter) {
      field?.remove();
      input.placeholder = form.dataset.placeholder || input.placeholder;
      return;
    }
    if (!field) {
      field = Object.assign(document.createElement("input"), { type: "hidden", name: "filter" });
      form.append(field);
    }
    field.value = filter;
    if (fixed) return;
    form.dataset.placeholder ||= input.placeholder;
    input.placeholder = "A name, or types such as Str -> Int";
    const chip = Object.assign(document.createElement("button"), { type: "button", className: CHIP_CLASS, textContent: filter });
    chip.setAttribute("aria-label", `Searching inside ${filter}. Remove this filter.`);
    chip.addEventListener("click", () => clearFilter());
    input.before(chip);
  }

  function narrowTo(project) {
    filter = project;
    input.value = "";
    renderChip();
    input.focus();
    load();
  }

  function clearFilter() {
    filter = "";
    renderChip();
    input.focus();
    input.value.trim() ? load() : close();
  }

  input.addEventListener("input", () => {
    forgetSelection();
    if (!input.value.trim() && !filter) return close();
    schedule();
  });
  input.addEventListener("focus", () => {
    if (input.value.trim() || filter) load();
  });
  input.addEventListener("keydown", (event) => {
    const row = rows[selected];
    if (event.key === "Backspace" && !input.value && filter && !fixed) {
      event.preventDefault();
      clearFilter();
    } else if (box.hidden) {
      if (event.key === "ArrowDown" && (input.value.trim() || filter)) {
        event.preventDefault();
        load();
      }
    } else if (event.key === "Escape") {
      event.preventDefault();
      close();
    } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      select(selected + (event.key === "ArrowDown" ? 1 : -1));
    } else if (event.key === "ArrowRight" && row?.dataset.kind === "project" && !fixed && input.selectionStart === input.value.length) {
      event.preventDefault();
      narrowTo(row.dataset.filter);
    } else if (event.key === "Enter") {
      event.preventDefault();
      if (row) location.assign(row.href);
      else if (input.value.trim()) form.requestSubmit();
    }
  });
  box.addEventListener("pointerdown", (event) => {
    if (!event.target.closest("a")) event.preventDefault();
  });
  box.addEventListener("pointermove", (event) => {
    const row = event.target.closest("a[role=option]");
    if (row && rows[selected] !== row) select(rows.indexOf(row));
  });
  document.addEventListener("pointerdown", (event) => {
    if (!form.contains(event.target)) close();
  });
  form.addEventListener("focusout", (event) => {
    if (!form.contains(event.relatedTarget)) close();
  });

  help?.addEventListener("toggle", place);
  window.addEventListener("resize", place);
  window.addEventListener("scroll", place, { passive: true, capture: true });

  renderChip();
}
