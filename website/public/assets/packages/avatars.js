export function bindAvatars(root = document) {
  for (const image of root.querySelectorAll(".package-avatar-image")) {
    const failed = () => image.remove();
    image.addEventListener("error", failed, { once: true });
    if (image.complete && image.naturalWidth === 0) failed();
  }
}

bindAvatars();
