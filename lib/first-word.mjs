// Returns the first whitespace-separated word of a text, or "" when there is none.
export function firstWord(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.trim().split(/\s+/)[0];
}
