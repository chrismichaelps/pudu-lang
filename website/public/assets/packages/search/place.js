const GAP = 6;
const MARGIN = 12;
const MIN_HEIGHT = 120;

/**
 * Pins a fixed panel under an anchor, inside the viewport. Panels are fixed
 * because page banners clip their overflow. `width` is the panel's preferred
 * width; without it the panel takes the anchor's width. `align` is "left" or
 * "right" edge of the anchor.
 */
export function placeBelow(panel, anchor, { width, align = "left" } = {}) {
  const rect = anchor.getBoundingClientRect();
  const wanted = Math.min(width ?? rect.width, window.innerWidth - MARGIN * 2);
  const preferred = align === "right" ? rect.right - wanted : rect.left;
  const left = Math.max(MARGIN, Math.min(preferred, window.innerWidth - MARGIN - wanted));
  const top = rect.bottom + GAP;
  panel.style.left = `${left}px`;
  panel.style.top = `${top}px`;
  panel.style.width = `${wanted}px`;
  panel.style.maxHeight = `${Math.max(MIN_HEIGHT, window.innerHeight - top - MARGIN)}px`;
}
