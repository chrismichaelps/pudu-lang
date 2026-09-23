// Opening an example, and resetting to the program the page opened with,
// without leaving the page.
//
// An example is read from its own page, which is where the server keeps it;
// the address bar follows, so Back returns to the previous example.

import { EXAMPLE_TIMEOUT_MS } from "../config/constants.js";
import { MESSAGES } from "../config/messages.js";
import { getText } from "../net/request.js";

export function bindExamples({ form, picker, resetLink, editor, signal, onReplaced }) {
  let original = editor.text();
  let loading = null;

  function modified() {
    return editor.text() !== original;
  }

  function markReset() {
    resetLink?.setAttribute("aria-disabled", String(!modified()));
  }

  function load(program) {
    original = program;
    onReplaced(program);
    markReset();
  }

  async function open(slug, remember) {
    const address = `${form.getAttribute("action")}/${encodeURIComponent(slug)}`;
    loading?.abort();
    const cancel = new AbortController();
    loading = cancel;
    try {
      const page = new DOMParser().parseFromString(
        await getText(address, { timeoutMs: EXAMPLE_TIMEOUT_MS, cancel: cancel.signal }),
        "text/html",
      );
      const program = page.getElementById("playground-source");
      if (!program) throw new Error("the example page holds no program");
      load(program.value);
      document.title = page.title || document.title;
      if (remember) history.pushState({ example: slug }, "", address);
      choose(slug);
    } catch (failure) {
      if (!failure?.cancelled) location.assign(address);
    } finally {
      if (loading === cancel) loading = null;
    }
  }

  function choose(slug) {
    if (!picker) return;
    picker.value = slug;
    picker.dataset.current = slug;
    picker.querySelector('option[value=""]')?.remove();
  }

  picker?.addEventListener("change", () => {
    const slug = picker.value;
    if (!slug) return;
    if (modified() && !confirm(MESSAGES.confirmExample)) {
      picker.value = picker.dataset.current ?? "";
      return;
    }
    open(slug, true);
  });
  if (picker) picker.dataset.current = picker.value;

  resetLink?.addEventListener("click", (event) => {
    event.preventDefault();
    if (modified() && confirm(MESSAGES.confirmReset)) load(original);
  });

  window.addEventListener("popstate", (event) => {
    const slug = event.state?.example;
    if (typeof slug === "string") open(slug, false);
    else location.reload();
  }, { signal });
  signal.addEventListener("abort", () => loading?.abort(), { once: true });

  markReset();
  return { changed: markReset };
}
