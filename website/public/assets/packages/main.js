for (const picker of document.querySelectorAll(".install-select")) {
  picker.addEventListener("change", () => {
    const panel = picker.closest(".install-panel");
    const command = panel?.querySelector(".install-picked");
    const label = command?.querySelector(".install-text");
    const copy = command?.querySelector(".install-copy");
    if (!command || !label || !copy) return;
    const name = command.dataset.package;
    const value = `pudu install ${name}${picker.value ? `@${picker.value}` : ""}`;
    label.textContent = value;
    copy.dataset.copy = value;
  });
}

for (const button of document.querySelectorAll(".install-copy")) {
  button.addEventListener("click", async () => {
    const value = button.dataset.copy;
    if (!value) return;
    try {
      await navigator.clipboard.writeText(value);
      button.textContent = "Copied";
      setTimeout(() => { button.textContent = "Copy"; }, 1800);
    } catch {
      button.textContent = "Select the command to copy";
    }
  });
}
