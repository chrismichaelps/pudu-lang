// What the page's contents follow while it is read.

// The contents' links to the page's own sections.
export const SECTION_LINKS = ".docs-toc a[href^='#']";

// How far below the top of the window a heading counts as the one being read:
// clear of the space a heading scrolled to by its link stops at.
export const READING_LINE_PX = 96;

// How close to the end of the page counts as the end, where the last section
// is the one being read even when its heading cannot reach the reading line.
export const END_SLACK_PX = 2;

// What a link to the section being read says it is.
export const CURRENT = "location";
