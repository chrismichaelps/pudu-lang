// Sharing a program as a link, from a dialog, without leaving the page.

import { MESSAGES } from "../config/messages.js";
import { focusWithoutScrolling } from "../dom/nodes.js";

export function bindShare({ endpoint, limit, editor, copyKeys }) {
  const dialog = document.getElementById("playground-share-dialog");
  const field = document.getElementById("playground-share-link");
  const note = document.getElementById("playground-share-note");
  const copy = document.getElementById("playground-copy");

  function open() {
    const link = `${location.origin}${endpoint}?code=${encodeURIComponent(editor.text())}`;
    if (!dialog || typeof dialog.showModal !== "function") {
      location.assign(link);
      return;
    }
    const fits = link.length <= limit;
    field.value = fits ? link : "";
    note.textContent = fits ? "" : MESSAGES.shareTooLong;
    copy.disabled = !fits;
    dialog.showModal();
    field.select();
  }

  copy?.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(field.value);
      note.textContent = MESSAGES.copied;
    } catch {
      field.select();
      note.textContent = MESSAGES.copyByHand(copyKeys);
    }
  });
  dialog?.addEventListener("close", () => focusWithoutScrolling(editor.source));
  document.getElementById("playground-link")?.addEventListener("focus", (event) => event.target.select());

  return { open };
}
