// Copy a code block's text.
//
// Each block ships its button hidden, so a page read without script never
// offers a button that does nothing. The text comes from the block itself
// rather than a copy kept in an attribute, which would double every block.

import { CODE_COPY, CODE_FIGURE, CODE_TEXT, COPIED_LABEL, COPIED_MILLIS, COPY_FAILED_LABEL } from "./constants.js";

export function bindCodeCopy(root = document) {
  if (!navigator.clipboard) return;
  for (const button of root.querySelectorAll(CODE_COPY)) {
    const code = button.closest(CODE_FIGURE)?.querySelector(CODE_TEXT);
    if (!code) continue;
    const label = button.textContent;
    button.hidden = false;
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        button.textContent = COPIED_LABEL;
      } catch {
        button.textContent = COPY_FAILED_LABEL;
      }
      setTimeout(() => { button.textContent = label; }, COPIED_MILLIS);
    });
  }
}

bindCodeCopy();
