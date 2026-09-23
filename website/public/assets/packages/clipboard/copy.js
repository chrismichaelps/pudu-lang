import { COPIED_LABEL, COPIED_MILLIS, COPY_FAILED_LABEL } from "../constants.js";

export function bindCopyButtons(root) {
  for (const button of root.querySelectorAll("[data-copy]")) {
    const label = button.textContent;
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        button.textContent = COPIED_LABEL;
      } catch {
        button.textContent = COPY_FAILED_LABEL;
      }
      setTimeout(() => { button.textContent = label; }, COPIED_MILLIS);
    });
  }
}
