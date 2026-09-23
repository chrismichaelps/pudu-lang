export function bindVersionPickers(root) {
  for (const picker of root.querySelectorAll(".install-select")) {
    picker.addEventListener("change", () => {
      const command = picker.closest(".install-panel")?.querySelector(".install-picked");
      const text = command?.querySelector(".install-text");
      const copy = command?.querySelector("[data-copy]");
      if (!command || !text || !copy) return;
      const value = `pudu install ${command.dataset.package}${picker.value ? `@${picker.value}` : ""}`;
      text.textContent = value;
      copy.dataset.copy = value;
    });
  }
}
