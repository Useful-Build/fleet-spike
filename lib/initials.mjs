// Returns the upper-cased first letter of each whitespace-separated word in text, joined with no separator.
export function initials(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  const trimmed = text.trim();
  if (trimmed === "") return "";
  return trimmed
    .split(/\s+/)
    .map((word) => word[0].toUpperCase())
    .join("");
}
