// Shortens text to at most max characters, ending a cut with a single "…".
export function truncate(text, max) {
  if (!Number.isInteger(max) || max < 1) throw new RangeError("max must be a whole number of 1 or more");
  if (text.length <= max) return text;
  return text.slice(0, max - 1) + "…";
}
