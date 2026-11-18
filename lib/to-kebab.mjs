// Turns text into kebab case: its words in lower case, joined by single dashes.
export function toKebab(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.trim().split(/\s+/).filter(Boolean).join("-").toLowerCase();
}
