import { TARGETS } from "./constants.js";

// The archive target for the reader's system, or "" when none is published for it.
export function readerTarget() {
  const named = (navigator.userAgentData?.platform || navigator.platform || navigator.userAgent || "").toLowerCase();
  if (named.includes("mac")) return TARGETS.mac;
  if (named.includes("android")) return "";
  if (named.includes("linux") && !/arm|aarch/.test(named)) return TARGETS.linux;
  return "";
}
